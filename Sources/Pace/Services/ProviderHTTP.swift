import Foundation

enum ProviderHTTP {
    static func data(for request: URLRequest, session: URLSession, unauthorizedHint: String) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ProviderError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.network(String(localized: "invalid response"))
        }
        switch http.statusCode {
        case 200..<300:
            return data
        case 401, 403:
            throw ProviderError.unauthorized(hint: unauthorizedHint)
        case 429:
            let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap { TimeInterval($0) }
            throw ProviderError.rateLimited(retryAfter: (retry ?? 0) > 0 ? retry : nil)
        default:
            throw ProviderError.network("HTTP \(http.statusCode)")
        }
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw ProviderError.decoding(error.localizedDescription)
        }
    }
}
