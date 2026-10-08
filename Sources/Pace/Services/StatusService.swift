import SwiftUI

enum StatusLevel: Sendable, Equatable {
    case operational
    case degraded
    case outage
    case unknown

    var isProblem: Bool { self == .degraded || self == .outage }

    var color: Color {
        switch self {
        case .operational: .green
        case .degraded: .orange
        case .outage: .red
        case .unknown: .secondary
        }
    }

    var icon: String {
        switch self {
        case .operational: "checkmark.circle.fill"
        case .degraded: "exclamationmark.triangle.fill"
        case .outage: "xmark.octagon.fill"
        case .unknown: "questionmark.circle"
        }
    }

    var label: String {
        switch self {
        case .operational: String(localized: "Operational")
        case .degraded: String(localized: "Degraded")
        case .outage: String(localized: "Outage")
        case .unknown: String(localized: "Unknown status")
        }
    }
}

struct ProviderStatus: Sendable, Equatable {
    var level: StatusLevel
    /// Composant le plus impacté, ex. « ChatGPT ». nil si tout va bien.
    var detail: String?

    static let unknown = ProviderStatus(level: .unknown, detail: nil)
}

/// Interroge les pages de statut Statuspage d'Anthropic et d'OpenAI et retient
/// le pire état parmi les composants qui nous concernent.
struct StatusService: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private struct Summary: Decodable {
        struct Component: Decodable { let name: String; let status: String }
        let components: [Component]?
    }

    func fetch(_ page: StatusPage) async -> ProviderStatus {
        var request = URLRequest(url: page.summaryURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "GET"

        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let summary = try? JSONDecoder().decode(Summary.self, from: data),
              let components = summary.components else {
            return .unknown
        }

        let matchers = page.componentMatchers.map { $0.lowercased() }
        var worst: StatusLevel = .operational
        var worstName: String?
        for component in components {
            let name = component.name.lowercased()
            guard matchers.contains(where: { name.contains($0) }) else { continue }
            let level = Self.level(from: component.status)
            if Self.rank(level) > Self.rank(worst) {
                worst = level
                worstName = component.name
            }
        }
        return ProviderStatus(level: worst, detail: worst.isProblem ? worstName : nil)
    }

    private static func level(from status: String) -> StatusLevel {
        switch status {
        case "operational", "under_maintenance": .operational
        case "degraded_performance", "partial_outage": .degraded
        case "major_outage": .outage
        default: .operational
        }
    }

    private static func rank(_ level: StatusLevel) -> Int {
        switch level {
        case .operational: 0
        case .unknown: 1
        case .degraded: 2
        case .outage: 3
        }
    }
}
