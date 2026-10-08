import Foundation

struct AvailableUpdate: Equatable, Sendable {
    let version: String
    let url: URL
}

enum UpdateChecker {
    private enum Key {
        static let lastCheck = "update.lastCheck"
        static let latestVersion = "update.latestVersion"
        static let latestURL = "update.latestURL"
    }

    private struct Release: Decodable {
        let tagName: String
        let htmlURL: URL
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    private static let interval: TimeInterval = 86400

    static var currentVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    static func availableUpdate(session: URLSession = .shared, now: Date = Date()) async -> AvailableUpdate? {
        guard let current = currentVersion else { return nil }
        let defaults = UserDefaults.standard
        let lastCheck = defaults.object(forKey: Key.lastCheck) as? Date
        if lastCheck.map({ now.timeIntervalSince($0) >= interval || $0 > now }) ?? true {
            var request = URLRequest(url: Endpoints.latestRelease, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            request.httpMethod = "GET"
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            if let (data, response) = try? await session.data(for: request), let http = response as? HTTPURLResponse {
                defaults.set(now, forKey: Key.lastCheck)
                if http.statusCode == 200,
                   let release = try? JSONDecoder().decode(Release.self, from: data),
                   release.htmlURL.scheme == "https", release.htmlURL.host() == "github.com" {
                    defaults.set(String(release.tagName.drop { $0 == "v" || $0 == "V" }), forKey: Key.latestVersion)
                    defaults.set(release.htmlURL, forKey: Key.latestURL)
                }
            }
        }
        guard let version = defaults.string(forKey: Key.latestVersion),
              let url = defaults.url(forKey: Key.latestURL),
              isNewer(version, than: current) else { return nil }
        return AvailableUpdate(version: version, url: url)
    }

    private static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = components(candidate)
        let b = components(current)
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : 0
            let y = index < b.count ? b[index] : 0
            if x != y { return x > y }
        }
        return false
    }

    private static func components(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
    }
}
