import Foundation
import OSLog

struct CodexCredentials: Sendable {
    var accessToken: String
    var refreshToken: String
    var idToken: String?
    var accountId: String?
    var lastRefresh: Date?

    /// Le CLI Codex rafraîchit quand le dernier refresh date de plus de 8 jours.
    var needsRefresh: Bool {
        guard !refreshToken.isEmpty else { return false }
        guard let lastRefresh else { return true }
        return Date().timeIntervalSince(lastRefresh) > 8 * 24 * 60 * 60
    }

    /// Account id pour l'en-tête `ChatGPT-Account-Id`.
    var resolvedAccountId: String? {
        if let accountId, !accountId.isEmpty { return accountId }
        for token in [idToken, accessToken].compactMap({ $0 }) {
            guard let claims = CodexAuth.decodeJWTPayload(token) else { continue }
            if let id = claims["chatgpt_account_id"] as? String, !id.isEmpty { return id }
            if let auth = claims["https://api.openai.com/auth"] as? [String: Any],
               let id = auth["chatgpt_account_id"] as? String, !id.isEmpty { return id }
        }
        return nil
    }
}

/// Lecture, refresh et réécriture atomique de ~/.codex/auth.json.
/// Sérialise les refresh pour ne jamais réutiliser un refresh token roté
/// (OpenAI révoque alors toute la famille de tokens).
actor CodexAuth {
    private let session: URLSession
    private var inflightRefresh: Task<CodexCredentials, Error>?
    private let logger = Logger(subsystem: "com.pierrickcoulon.Pace", category: "codex-auth")

    init(session: URLSession = .shared) {
        self.session = session
    }

    static var authFileURL: URL {
        if let home = ProcessInfo.processInfo.environment["CODEX_HOME"], !home.isEmpty {
            return URL(fileURLWithPath: (home as NSString).expandingTildeInPath).appendingPathComponent("auth.json")
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/auth.json")
    }

    static func fileExists() -> Bool {
        FileManager.default.fileExists(atPath: authFileURL.path)
    }

    func load() throws -> CodexCredentials {
        guard FileManager.default.fileExists(atPath: Self.authFileURL.path),
              let data = try? Data(contentsOf: Self.authFileURL),
              let credentials = Self.parse(data) else {
            throw ProviderError.notConfigured(hint: "Lance `codex login`")
        }
        return credentials
    }

    func refreshIfNeeded(_ credentials: CodexCredentials, force: Bool = false) async throws -> CodexCredentials {
        guard (credentials.needsRefresh || force), !credentials.refreshToken.isEmpty else {
            return credentials
        }
        if let inflightRefresh { return try await inflightRefresh.value }
        let task = Task<CodexCredentials, Error> {
            defer { inflightRefresh = nil }
            let refreshed = try await refresh(credentials)
            try? Self.writeBack(refreshed)
            return refreshed
        }
        inflightRefresh = task
        return try await task.value
    }

    private func refresh(_ credentials: CodexCredentials) async throws -> CodexCredentials {
        var request = URLRequest(url: Endpoints.codexTokenRefresh)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "client_id": Endpoints.codexClientID,
            "grant_type": "refresh_token",
            "refresh_token": credentials.refreshToken,
            "scope": "openid profile email",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ProviderError.network(error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.unauthorized(hint: "Session Codex expirée, relance `codex login`")
        }
        return CodexCredentials(
            accessToken: json["access_token"] as? String ?? credentials.accessToken,
            refreshToken: json["refresh_token"] as? String ?? credentials.refreshToken,
            idToken: json["id_token"] as? String ?? credentials.idToken,
            accountId: credentials.accountId,
            lastRefresh: Date()
        )
    }

    // MARK: - Parsing / sérialisation

    static func parse(_ data: Data) -> CodexCredentials? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let apiKey = json["OPENAI_API_KEY"] as? String,
           !apiKey.trimmingCharacters(in: .whitespaces).isEmpty,
           json["tokens"] == nil {
            return CodexCredentials(accessToken: apiKey, refreshToken: "", idToken: nil, accountId: nil, lastRefresh: nil)
        }
        guard let tokens = json["tokens"] as? [String: Any],
              let access = string(tokens, "access_token", "accessToken"), !access.isEmpty else {
            if let apiKey = json["OPENAI_API_KEY"] as? String,
               !apiKey.trimmingCharacters(in: .whitespaces).isEmpty {
                return CodexCredentials(accessToken: apiKey, refreshToken: "", idToken: nil, accountId: nil, lastRefresh: nil)
            }
            return nil
        }
        return CodexCredentials(
            accessToken: access,
            refreshToken: string(tokens, "refresh_token", "refreshToken") ?? "",
            idToken: string(tokens, "id_token", "idToken"),
            accountId: string(tokens, "account_id", "accountId"),
            lastRefresh: parseDate(json["last_refresh"])
        )
    }

    /// Réécriture atomique : fichier temporaire dans le même dossier, permissions
    /// 0600, puis rename(2). Préserve les clés top-level inconnues.
    static func writeBack(_ credentials: CodexCredentials) throws {
        let url = authFileURL
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: url),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }
        var tokens: [String: Any] = [
            "access_token": credentials.accessToken,
            "refresh_token": credentials.refreshToken,
        ]
        if let idToken = credentials.idToken { tokens["id_token"] = idToken }
        if let accountId = credentials.accountId { tokens["account_id"] = accountId }
        json["tokens"] = tokens
        json["last_refresh"] = ISO8601.string(from: credentials.lastRefresh ?? Date())

        guard let out = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) else {
            throw ProviderError.decoding("sérialisation auth.json")
        }
        let staged = url.deletingLastPathComponent()
            .appendingPathComponent(".auth.json.usagebar-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: staged.path, contents: out, attributes: [.posixPermissions: 0o600])
        if rename(staged.path, url.path) != 0 {
            try? FileManager.default.removeItem(at: staged)
            throw ProviderError.decoding("écriture auth.json (errno \(errno))")
        }
    }

    static func decodeJWTPayload(_ jwt: String) -> [String: Any]? {
        let segments = jwt.components(separatedBy: ".")
        guard segments.count >= 2 else { return nil }
        var base64 = segments[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func string(_ dict: [String: Any], _ a: String, _ b: String) -> String? {
        if let v = dict[a] as? String, !v.isEmpty { return v }
        if let v = dict[b] as? String, !v.isEmpty { return v }
        return nil
    }

    private static func parseDate(_ raw: Any?) -> Date? {
        guard let value = raw as? String else { return nil }
        return ISO8601.date(from: value)
    }
}
