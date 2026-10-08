import Foundation

actor CopilotUsageProvider: UsageProvider {
    nonisolated let id: ProviderID = .copilot

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchUsage() async throws -> ProviderUsage {
        guard let token = CopilotTokenReader.read() else {
            throw ProviderError.notConfigured(hint: String(localized: "Run `gh auth login` or sign in to Copilot in your editor"))
        }
        var request = URLRequest(url: Endpoints.copilotUsage, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        let headers = [
            "Authorization": "token \(token.value)",
            "Accept": "application/json",
            "Editor-Version": "vscode/1.96.2",
            "Editor-Plugin-Version": "copilot-chat/0.26.7",
            "User-Agent": "GitHubCopilotChat/0.26.7",
            "X-Github-Api-Version": "2025-04-01",
        ]
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }

        let data = try await ProviderHTTP.data(for: request, session: session, unauthorizedHint: String(localized: "GitHub token rejected, run `gh auth login` again"))
        let decoded = try ProviderHTTP.decode(CopilotUsageResponse.self, from: data)
        let (long, models) = decoded.mapped()
        let extra = decoded.extra()
        guard long != nil || !models.isEmpty || extra != nil || decoded.tokenBasedBilling == true else {
            throw ProviderError.notConfigured(hint: String(localized: "No Copilot quota for this account"))
        }
        return ProviderUsage(
            shortWindow: nil,
            longWindow: long,
            models: models,
            extra: extra,
            plan: PlanName.display(decoded.copilotPlan),
            source: token.source,
            fetchedAt: Date()
        )
    }
}

struct CopilotToken: Sendable {
    let value: String
    let source: String
}

enum CopilotTokenReader {
    private static let ghKeychainService = "gh:github.com"

    private static var configDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config")
    }

    private static var editorConfigURLs: [URL] {
        ["github-copilot/apps.json", "github-copilot/hosts.json"].map { configDirectory.appendingPathComponent($0) }
    }

    private static var ghHostsURL: URL {
        configDirectory.appendingPathComponent("gh/hosts.yml")
    }

    static func hasEditorConfig() -> Bool {
        editorConfigURLs.contains { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func read() -> CopilotToken? {
        fromEditorConfig() ?? fromGhHosts() ?? fromGhKeychain()
    }

    private static func fromEditorConfig() -> CopilotToken? {
        for url in editorConfigURLs {
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            for (host, value) in json where host == "github.com" || host.hasPrefix("github.com:") {
                guard let token = ((value as? [String: Any])?["oauth_token"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else { continue }
                return CopilotToken(value: token, source: String(localized: "Copilot extension"))
            }
        }
        return nil
    }

    private static func fromGhHosts() -> CopilotToken? {
        ghHostsValue("oauth_token").map { CopilotToken(value: $0, source: "gh auth login") }
    }

    private static func fromGhKeychain() -> CopilotToken? {
        let base = ["find-generic-password", "-s", ghKeychainService]
        let raw = ghHostsValue("user").flatMap { securityOutput(base + ["-a", $0, "-w"]) } ?? securityOutput(base + ["-w"])
        return raw.flatMap(unwrapGoKeyring).map { CopilotToken(value: $0, source: "gh auth login") }
    }

    private static func ghHostsValue(_ key: String) -> String? {
        guard let text = try? String(contentsOf: ghHostsURL, encoding: .utf8) else { return nil }
        let prefix = key + ":"
        var inGitHub = false
        for line in text.split(whereSeparator: \.isNewline) {
            if let first = line.first, !first.isWhitespace {
                inGitHub = line.trimmingCharacters(in: .whitespaces).hasPrefix("github.com:")
                continue
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard inGitHub, trimmed.hasPrefix(prefix) else { continue }
            let value = trimmed.dropFirst(prefix.count)
                .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\"'")))
            return value.isEmpty ? nil : value
        }
        return nil
    }

    private static func securityOutput(_ arguments: [String]) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        task.arguments = arguments
        let stdout = Pipe()
        task.standardOutput = stdout
        task.standardError = Pipe()
        do {
            try task.run()
        } catch {
            return nil
        }
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            task.waitUntilExit()
            done.signal()
        }
        if done.wait(timeout: .now() + 3) == .timedOut {
            task.terminate()
            return nil
        }
        guard task.terminationStatus == 0 else { return nil }
        return String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    }

    private static func unwrapGoKeyring(_ raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "go-keyring-base64:"
        if text.hasPrefix(prefix) {
            guard let data = Data(base64Encoded: String(text.dropFirst(prefix.count))),
                  let decoded = String(data: data, encoding: .utf8) else { return nil }
            text = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.isEmpty ? nil : text
    }
}
