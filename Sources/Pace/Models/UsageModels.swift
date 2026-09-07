import Foundation

enum ProviderKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case claude
    case codex

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        }
    }

    var glyph: String {
        switch self {
        case .claude: "C"
        case .codex: "X"
        }
    }

    /// Page d'usage officielle, ouverte au clic sur la carte.
    var usagePageURL: URL {
        switch self {
        case .claude: URL(string: "https://claude.ai/settings/usage")!
        case .codex: URL(string: "https://chatgpt.com/#settings/Usage")!
        }
    }
}

struct UsageWindow: Sendable, Equatable, Codable {
    var utilization: Double
    var resetsAt: Date?
    /// Durée totale de la fenêtre en secondes (18000 = 5 h, 604800 = 7 j).
    /// Sert au calcul de rythme.
    var windowSeconds: TimeInterval?
}

struct ModelUsage: Sendable, Equatable, Identifiable, Codable {
    var name: String
    var window: UsageWindow

    var id: String { name }
}

struct ExtraUsage: Sendable, Equatable, Codable {
    var label: String
    var detail: String
    var fraction: Double?
}

struct ProviderUsage: Sendable, Equatable, Codable {
    var fiveHour: UsageWindow?
    var weekly: UsageWindow?
    var models: [ModelUsage] = []
    var extra: ExtraUsage?
    var plan: String?
    var fetchedAt: Date
}

enum ProviderError: Error, Sendable, Equatable {
    case notConfigured(hint: String)
    case unauthorized(hint: String)
    case rateLimited(retryAfter: TimeInterval?)
    case network(String)
    case decoding(String)

    var message: String {
        switch self {
        case .notConfigured(let hint), .unauthorized(let hint):
            hint
        case .rateLimited(let retryAfter):
            if let retryAfter {
                "Trop de requêtes, nouvel essai dans \(UsageFormat.duration(retryAfter))"
            } else {
                "Trop de requêtes, nouvel essai plus tard"
            }
        case .network(let detail):
            "Réseau : \(detail)"
        case .decoding(let detail):
            "Réponse inattendue : \(detail)"
        }
    }

    var isAuthFailure: Bool {
        switch self {
        case .notConfigured, .unauthorized: true
        default: false
        }
    }
}

enum ProviderState: Sendable, Equatable {
    case idle
    case loaded(ProviderUsage)
    case failed(ProviderError, last: ProviderUsage?)

    var usage: ProviderUsage? {
        switch self {
        case .idle: nil
        case .loaded(let usage): usage
        case .failed(_, let last): last
        }
    }

    var error: ProviderError? {
        if case .failed(let error, _) = self { return error }
        return nil
    }
}
