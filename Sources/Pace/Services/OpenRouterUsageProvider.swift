import Foundation

extension SecretAccount {
    static let openRouterAPIKey = "openrouter.apiKey"
}

actor OpenRouterUsageProvider: UsageProvider {
    nonisolated let id: ProviderID = .openRouter

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    static func hasKey() -> Bool {
        SecretStore.get(SecretAccount.openRouterAPIKey) != nil
    }

    func fetchUsage() async throws -> ProviderUsage {
        guard let key = SecretStore.get(SecretAccount.openRouterAPIKey) else {
            throw ProviderError.notConfigured(hint: String(localized: "Paste a key from openrouter.ai/keys"))
        }
        async let keyData = get(Endpoints.openRouterKey, key: key)
        async let creditsData = get(Endpoints.openRouterCredits, key: key)
        let keyInfo = try ProviderHTTP.decode(OpenRouterKeyResponse.self, from: try await keyData)
        let credits = (try? await creditsData).flatMap { try? JSONDecoder().decode(OpenRouterCreditsResponse.self, from: $0) }

        let window = keyInfo.window()
        let extra = credits?.extra()
        guard window != nil || extra != nil else {
            throw ProviderError.notConfigured(hint: String(localized: "No limit or credit visible with this key"))
        }
        let isShort = window?.windowSeconds.map { WindowSlot(windowSeconds: $0) == .short } ?? false
        return ProviderUsage(
            shortWindow: isShort ? window : nil,
            longWindow: isShort ? nil : window,
            models: [],
            extra: extra,
            plan: keyInfo.plan,
            source: String(localized: "API key"),
            fetchedAt: Date()
        )
    }

    private func get(_ url: URL, key: String) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await ProviderHTTP.data(for: request, session: session, unauthorizedHint: String(localized: "Invalid OpenRouter key, paste it again in Settings"))
    }
}
