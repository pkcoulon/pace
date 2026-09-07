import Foundation

/// Provider Codex. Lit ~/.codex/auth.json, rafraîchit le token si nécessaire,
/// appelle /backend-api/wham/usage, et sur un 401 force un refresh puis réessaie.
actor CodexUsageProvider: UsageProvider {
    nonisolated let kind: ProviderKind = .codex

    private let session: URLSession
    private let auth: CodexAuth

    init(session: URLSession = .shared) {
        self.session = session
        self.auth = CodexAuth(session: session)
    }

    func fetchUsage() async throws -> ProviderUsage {
        guard CodexAuth.fileExists() else {
            throw ProviderError.notConfigured(hint: "Lance `codex login`")
        }
        var credentials = try await auth.load()
        credentials = try await auth.refreshIfNeeded(credentials)
        do {
            return try await fetch(credentials)
        } catch let error as ProviderError where error.isAuthFailure {
            guard !credentials.refreshToken.isEmpty else { throw error }
            let refreshed = try await auth.refreshIfNeeded(credentials, force: true)
            return try await fetch(refreshed)
        }
    }

    private func fetch(_ credentials: CodexCredentials) async throws -> ProviderUsage {
        var request = URLRequest(url: Endpoints.codexUsage, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accountId = credentials.resolvedAccountId, !accountId.isEmpty {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ProviderError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.network("réponse invalide")
        }
        switch http.statusCode {
        case 200:
            return try map(data)
        case 401, 403:
            throw ProviderError.unauthorized(hint: "Session Codex expirée, relance `codex login`")
        case 429:
            let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap { TimeInterval($0) }
            throw ProviderError.rateLimited(retryAfter: (retry ?? 0) > 0 ? retry : nil)
        default:
            throw ProviderError.network("HTTP \(http.statusCode)")
        }
    }

    private func map(_ data: Data) throws -> ProviderUsage {
        let decoded: CodexUsageResponse
        do {
            decoded = try JSONDecoder().decode(CodexUsageResponse.self, from: data)
        } catch {
            throw ProviderError.decoding(error.localizedDescription)
        }
        let (five, weekly) = decoded.mapped()
        return ProviderUsage(
            fiveHour: five,
            weekly: weekly,
            models: [],
            extra: decoded.extra(),
            plan: PlanName.display(decoded.planType),
            fetchedAt: Date()
        )
    }
}
