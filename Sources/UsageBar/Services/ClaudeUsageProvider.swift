import Foundation

/// Provider Claude. Mode principal : token OAuth de Claude Code (api.anthropic.com).
/// Mode secours : session key claude.ai (claude.ai/api) quand aucun token OAuth
/// n'est disponible. Ne rafraîchit jamais le token OAuth lui-même.
actor ClaudeUsageProvider: UsageProvider {
    nonisolated let kind: ProviderKind = .claude

    private let session: URLSession
    private var cachedOrgUUID: String?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchUsage() async throws -> ProviderUsage {
        if let credential = ClaudeTokenReader.read() {
            return try await fetchOAuth(credential)
        }
        if let key = SecretStore.get(SecretAccount.claudeSessionKey) {
            return try await fetchSessionKey(key)
        }
        throw ProviderError.notConfigured(hint: "Lance `claude` ou ajoute une session key dans les réglages")
    }

    // MARK: - OAuth (Claude Code)

    private func fetchOAuth(_ credential: ClaudeOAuthCredential) async throws -> ProviderUsage {
        var request = URLRequest(url: Endpoints.claudeOAuthUsage)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Endpoints.anthropicBeta, forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/\(ClaudeCodeVersion.detect())", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await send(request)
        switch response.statusCode {
        case 200:
            return try map(data, plan: credential.subscriptionType)
        case 401, 403:
            throw ProviderError.unauthorized(hint: "Token expiré, relance `claude`")
        case 429:
            throw ProviderError.rateLimited(retryAfter: retryAfter(response))
        default:
            throw ProviderError.network("HTTP \(response.statusCode)")
        }
    }

    // MARK: - Session key (claude.ai)

    private func fetchSessionKey(_ key: String) async throws -> ProviderUsage {
        let orgUUID = try await organizationUUID(key)
        var request = URLRequest(url: Endpoints.claudeWebUsage(orgUUID: orgUUID))
        request.httpMethod = "GET"
        applyWebHeaders(&request, sessionKey: key)

        let (data, response) = try await send(request)
        try throwIfCloudflare(data, status: response.statusCode)
        switch response.statusCode {
        case 200:
            if let error = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data), error.isPermissionError {
                throw ProviderError.unauthorized(hint: "Session key expirée, recolle-la dans les réglages")
            }
            return try map(data, plan: nil)
        case 401, 403:
            throw ProviderError.unauthorized(hint: "Session key invalide ou expirée")
        case 429:
            throw ProviderError.rateLimited(retryAfter: retryAfter(response))
        default:
            throw ProviderError.network("HTTP \(response.statusCode)")
        }
    }

    private func organizationUUID(_ key: String) async throws -> String {
        if let cached = cachedOrgUUID { return cached }
        var request = URLRequest(url: Endpoints.claudeWebOrganizations)
        request.httpMethod = "GET"
        applyWebHeaders(&request, sessionKey: key)

        let (data, response) = try await send(request)
        try throwIfCloudflare(data, status: response.statusCode)
        guard response.statusCode == 200 else {
            if response.statusCode == 401 || response.statusCode == 403 {
                throw ProviderError.unauthorized(hint: "Session key invalide ou expirée")
            }
            throw ProviderError.network("HTTP \(response.statusCode)")
        }
        guard let orgs = try? JSONDecoder().decode([ClaudeOrganization].self, from: data), let first = orgs.first else {
            throw ProviderError.decoding("aucune organisation")
        }
        cachedOrgUUID = first.uuid
        return first.uuid
    }

    private func applyWebHeaders(_ request: inout URLRequest, sessionKey: String) {
        request.assumesHTTP3Capable = false
        let headers: [String: String] = [
            "accept": "*/*",
            "accept-language": "fr-FR,fr;q=0.9,en;q=0.8",
            "content-type": "application/json",
            "anthropic-client-platform": "web_claude_ai",
            "anthropic-client-version": "1.0.0",
            "user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
            "origin": "https://claude.ai",
            "referer": "https://claude.ai/settings/usage",
            "sec-fetch-dest": "empty",
            "sec-fetch-mode": "cors",
            "sec-fetch-site": "same-origin",
            "Cookie": "sessionKey=\(sessionKey)",
        ]
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
    }

    private func throwIfCloudflare(_ data: Data, status: Int) throws {
        guard let text = String(data: data, encoding: .utf8) else { return }
        if text.contains("<!DOCTYPE html") || text.contains("<html") {
            throw ProviderError.network("Cloudflare bloque la requête claude.ai")
        }
    }

    // MARK: - Commun

    private func map(_ data: Data, plan: String?) throws -> ProviderUsage {
        let decoded: ClaudeUsageResponse
        do {
            decoded = try JSONDecoder().decode(ClaudeUsageResponse.self, from: data)
        } catch {
            throw ProviderError.decoding(error.localizedDescription)
        }
        guard !decoded.hasNoWindows else {
            throw ProviderError.notConfigured(hint: "Aucune donnée d'usage pour ce compte")
        }
        return ProviderUsage(
            fiveHour: decoded.fiveHour.map { UsageWindow(utilization: $0.utilization, resetsAt: $0.resetsAtDate) },
            weekly: decoded.sevenDay.map { UsageWindow(utilization: $0.utilization, resetsAt: $0.resetsAtDate) },
            models: decoded.modelUsages(),
            extra: decoded.extra(),
            plan: PlanName.display(plan),
            fetchedAt: Date()
        )
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw ProviderError.network("réponse invalide")
            }
            return (data, http)
        } catch let error as ProviderError {
            throw error
        } catch {
            throw ProviderError.network(error.localizedDescription)
        }
    }

    private func retryAfter(_ response: HTTPURLResponse) -> TimeInterval? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After"),
              let seconds = TimeInterval(raw), seconds > 0 else { return nil }
        return seconds
    }

    // MARK: - Test session key (réglages)

    static func testSessionKey(_ key: String) async -> Result<String, ProviderError> {
        let provider = ClaudeUsageProvider()
        do {
            let usage = try await provider.fetchSessionKey(key)
            let five = usage.fiveHour.map { "5 h \(Int($0.utilization))%" } ?? ""
            return .success("Connecté. \(five)".trimmingCharacters(in: .whitespaces))
        } catch let error as ProviderError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }
}
