import Foundation
import SQLite3

actor CursorUsageProvider: UsageProvider {
    nonisolated let id: ProviderID = .cursor

    private static let expiredHint = String(localized: "Cursor session expired, open Cursor")

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchUsage() async throws -> ProviderUsage {
        guard let token = CursorTokenReader.readAccessToken() else {
            throw ProviderError.notConfigured(hint: String(localized: "Sign in to the Cursor app"))
        }
        if let exp = (CodexAuth.decodeJWTPayload(token)?["exp"] as? NSNumber)?.doubleValue,
           Date(timeIntervalSince1970: exp) <= Date() {
            throw ProviderError.unauthorized(hint: Self.expiredHint)
        }
        async let usageData = post(Endpoints.cursorUsage, token: token)
        async let planData = post(Endpoints.cursorPlanInfo, token: token)
        let usage = try ProviderHTTP.decode(CursorUsageResponse.self, from: try await usageData)
        let planName = (try? await planData).flatMap { try? JSONDecoder().decode(CursorPlanInfoResponse.self, from: $0) }?.planName

        guard let mapped = usage.mapped(planName: planName) else {
            throw ProviderError.notConfigured(hint: String(localized: "No active Cursor subscription"))
        }
        guard mapped.long != nil || !mapped.models.isEmpty else {
            throw ProviderError.notConfigured(hint: String(localized: "Cursor usage unavailable for this account type"))
        }
        return ProviderUsage(
            shortWindow: nil,
            longWindow: mapped.long,
            models: mapped.models,
            extra: usage.onDemand(),
            plan: PlanName.display(planName),
            source: String(localized: "Cursor app"),
            fetchedAt: Date()
        )
    }

    private func post(_ url: URL, token: String) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.httpBody = Data("{}".utf8)
        return try await ProviderHTTP.data(for: request, session: session, unauthorizedHint: Self.expiredHint)
    }
}

enum CursorTokenReader {
    private struct SQLiteFailure: Error {
        let code: Int32
    }

    private static var stateDBURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
    }

    static func dbExists() -> Bool {
        FileManager.default.fileExists(atPath: stateDBURL.path)
    }

    static func readAccessToken() -> String? {
        guard dbExists() else { return nil }
        switch query(immutable: false) {
        case .success(let value):
            return value
        case .failure(let failure):
            let path = stateDBURL.path
            guard failure.code == SQLITE_CANTOPEN,
                  !FileManager.default.fileExists(atPath: path + "-wal"),
                  !FileManager.default.fileExists(atPath: path + "-shm") else { return nil }
            return (try? query(immutable: true).get()) ?? nil
        }
    }

    private static func query(immutable: Bool) -> Result<String?, SQLiteFailure> {
        var db: OpaquePointer?
        let filename = immutable ? stateDBURL.absoluteString + "?immutable=1" : stateDBURL.path
        let flags = immutable ? SQLITE_OPEN_READONLY | SQLITE_OPEN_URI : SQLITE_OPEN_READONLY
        let opened = sqlite3_open_v2(filename, &db, flags, nil)
        defer { sqlite3_close(db) }
        guard opened == SQLITE_OK else { return .failure(SQLiteFailure(code: opened)) }
        sqlite3_busy_timeout(db, 250)

        var statement: OpaquePointer?
        let sql = "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken' LIMIT 1"
        let prepared = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        defer { sqlite3_finalize(statement) }
        guard prepared == SQLITE_OK else { return .failure(SQLiteFailure(code: prepared)) }

        let step = sqlite3_step(statement)
        guard step == SQLITE_ROW else {
            return step == SQLITE_DONE ? .success(nil) : .failure(SQLiteFailure(code: step))
        }
        return .success(text(statement))
    }

    private static func text(_ statement: OpaquePointer?) -> String? {
        let raw: String?
        switch sqlite3_column_type(statement, 0) {
        case SQLITE_TEXT:
            raw = sqlite3_column_text(statement, 0).map { String(cString: $0) }
        case SQLITE_BLOB:
            guard let bytes = sqlite3_column_blob(statement, 0) else { return nil }
            let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0)))
            let isASCIIUTF16 = data.count.isMultiple(of: 2)
                && stride(from: 0, to: data.count, by: 2).allSatisfy { (1..<128).contains(data[$0]) && data[$0 + 1] == 0 }
            raw = String(data: data, encoding: isASCIIUTF16 ? .utf16LittleEndian : .utf8)
        default:
            raw = nil
        }
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
