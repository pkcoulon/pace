import Foundation

enum GitHubDeviceFlow {
    static let defaultHost = "github.com"

    struct DeviceCode: Sendable {
        let deviceCode: String
        let userCode: String
        let verificationURL: URL
        let interval: Int
        let expiresIn: Int
    }

    static func normalizedHost(_ raw: String) -> String? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return defaultHost }
        let host = URLComponents(string: text.contains("://") ? text : "https://" + text)?.host?
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard let host, host.contains(".") else { return nil }
        return host
    }

    static func requestCode(host: String, session: URLSession = .shared) async throws -> DeviceCode {
        let json = try await post(Endpoints.githubDeviceCode(host: host), ["client_id": Endpoints.githubClientID, "scope": "read:user"], session: session)
        guard let deviceCode = json["device_code"] as? String,
              let userCode = json["user_code"] as? String,
              let verificationURL = (json["verification_uri"] as? String).flatMap(URL.init(string:)) else {
            throw failure(json)
        }
        return DeviceCode(
            deviceCode: deviceCode,
            userCode: userCode,
            verificationURL: verificationURL,
            interval: json["interval"] as? Int ?? 5,
            expiresIn: json["expires_in"] as? Int ?? 900
        )
    }

    static func waitForToken(_ code: DeviceCode, host: String, session: URLSession = .shared) async throws -> String {
        let body = [
            "client_id": Endpoints.githubClientID,
            "device_code": code.deviceCode,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
        ]
        var interval = code.interval
        let deadline = Date().addingTimeInterval(TimeInterval(code.expiresIn))
        while Date() < deadline {
            try await Task.sleep(for: .seconds(interval))
            let json = try await post(Endpoints.githubAccessToken(host: host), body, session: session)
            if let token = json["access_token"] as? String, !token.isEmpty {
                return token
            }
            switch json["error"] as? String {
            case "authorization_pending":
                continue
            case "slow_down":
                interval = json["interval"] as? Int ?? interval + 5
            case "expired_token":
                throw ProviderError.unauthorized(hint: String(localized: "Code expired, sign in again"))
            case "access_denied":
                throw ProviderError.unauthorized(hint: String(localized: "Sign-in declined on GitHub"))
            default:
                throw failure(json)
            }
        }
        throw ProviderError.unauthorized(hint: String(localized: "Code expired, sign in again"))
    }

    private static func post(_ url: URL, _ body: [String: String], session: URLSession) async throws -> [String: Any] {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data = try await ProviderHTTP.data(for: request, session: session, unauthorizedHint: String(localized: "GitHub refused the sign-in"))
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.decoding(String(localized: "invalid response"))
        }
        return json
    }

    private static func failure(_ json: [String: Any]) -> ProviderError {
        .network(json["error_description"] as? String ?? json["error"] as? String ?? String(localized: "invalid response"))
    }
}
