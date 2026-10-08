import Foundation

extension SecretAccount {
    static let zaiAPIKey = "zai.apiKey"
}

actor ZaiUsageProvider: UsageProvider {
    nonisolated let id: ProviderID = .zai

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchUsage() async throws -> ProviderUsage {
        guard let credential = ZaiCredentialReader.read() else {
            throw ProviderError.notConfigured(hint: String(localized: "Paste your z.ai API key in Settings"))
        }
        var request = URLRequest(url: credential.quotaURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credential.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")

        let data = try await ProviderHTTP.data(for: request, session: session, unauthorizedHint: credential.unauthorizedHint)
        let decoded = try ProviderHTTP.decode(ZaiQuotaResponse.self, from: data)
        if decoded.isNoCodingPlan {
            throw ProviderError.notConfigured(hint: String(localized: "No active GLM Coding Plan on this account"))
        }
        guard decoded.success != false, decoded.limits != nil else {
            throw ProviderError.decoding(decoded.msg ?? String(localized: "missing limits"))
        }
        let (short, long, models) = decoded.mapped()
        guard short != nil || long != nil || !models.isEmpty else {
            throw ProviderError.notConfigured(hint: String(localized: "No usage data for this account"))
        }
        return ProviderUsage(
            shortWindow: short,
            longWindow: long,
            models: models,
            extra: nil,
            plan: PlanName.display(decoded.level),
            source: credential.source,
            fetchedAt: Date()
        )
    }
}

struct ZaiCredential: Sendable {
    let apiKey: String
    let quotaURL: URL
    let source: String
    let unauthorizedHint: String
}

enum ZaiCredentialReader {
    private static let claudeSettingsHosts: Set<String> = ["api.z.ai", "open.bigmodel.cn", "dev.bigmodel.cn"]

    static func isAvailable() -> Bool {
        SecretStore.get(SecretAccount.zaiAPIKey) != nil || fromClaudeSettings() != nil
    }

    static func read() -> ZaiCredential? {
        if let key = SecretStore.get(SecretAccount.zaiAPIKey) {
            return ZaiCredential(
                apiKey: key,
                quotaURL: Endpoints.zaiQuota(origin: Endpoints.zaiGlobal),
                source: String(localized: "API key"),
                unauthorizedHint: String(localized: "z.ai API key rejected, paste it again in Settings")
            )
        }
        return fromClaudeSettings()
    }

    private static func fromClaudeSettings() -> ZaiCredential? {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let env = json["env"] as? [String: Any],
              let token = (env["ANTHROPIC_AUTH_TOKEN"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty,
              let raw = env["ANTHROPIC_BASE_URL"] as? String,
              let base = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              base.scheme?.lowercased() == "https",
              let host = base.host?.lowercased(),
              claudeSettingsHosts.contains(host),
              let origin = URL(string: "https://\(host)") else {
            return nil
        }
        return ZaiCredential(
            apiKey: token,
            quotaURL: Endpoints.zaiQuota(origin: origin),
            source: String(localized: "Claude Code settings"),
            unauthorizedHint: String(localized: "z.ai key rejected, check ~/.claude/settings.json")
        )
    }
}
