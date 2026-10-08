import Foundation

struct ProviderID: RawRepresentable, Hashable, Sendable, Codable, Identifiable, CodingKeyRepresentable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    var id: String { rawValue }

    static let claude = ProviderID(rawValue: "claude")
    static let codex = ProviderID(rawValue: "codex")
}

enum WindowSlot: String, Codable, CaseIterable, Sendable, CodingKeyRepresentable {
    case short
    case long

    init(windowSeconds: TimeInterval) {
        self = windowSeconds <= 86400 ? .short : .long
    }
}

struct UsageWindow: Sendable, Equatable, Codable {
    var utilization: Double
    var resetsAt: Date?
    /// Durée totale de la fenêtre en secondes (18000 = 5 h, 604800 = 7 j).
    /// Sert au calcul de rythme.
    var windowSeconds: TimeInterval?

    var label: String {
        guard let seconds = windowSeconds, seconds > 0 else { return String(localized: "Window") }
        switch Int((seconds / 3600).rounded()) {
        case 24: return String(localized: "Day")
        case 168: return String(localized: "Week")
        case 672...744: return String(localized: "Month")
        default: return UsageFormat.duration(seconds)
        }
    }

    func isExpired(at now: Date) -> Bool {
        resetsAt.map { $0 <= now } ?? false
    }

    func effective(at now: Date) -> UsageWindow {
        guard let resetsAt, resetsAt <= now else { return self }
        var next: Date?
        if let seconds = windowSeconds, seconds > 0, WindowSlot(windowSeconds: seconds) == .long {
            let cycles = (now.timeIntervalSince(resetsAt) / seconds).rounded(.down) + 1
            next = resetsAt.addingTimeInterval(cycles * seconds)
        }
        return UsageWindow(utilization: 0, resetsAt: next, windowSeconds: windowSeconds)
    }

    static func sameCycle(_ a: Date?, _ b: Date?) -> Bool {
        guard let a, let b else { return a == b }
        return abs(a.timeIntervalSince(b)) <= 15 * 60
    }
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
    var shortWindow: UsageWindow?
    var longWindow: UsageWindow?
    var models: [ModelUsage] = []
    var extra: ExtraUsage?
    var plan: String?
    var source: String?
    var fetchedAt: Date

    func window(_ slot: WindowSlot) -> UsageWindow? {
        switch slot {
        case .short: shortWindow
        case .long: longWindow
        }
    }

    func effective(at now: Date) -> ProviderUsage {
        var usage = self
        usage.shortWindow = shortWindow?.effective(at: now)
        usage.longWindow = longWindow?.effective(at: now)
        usage.models = models.map { ModelUsage(name: $0.name, window: $0.window.effective(at: now)) }
        return usage
    }
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
                String(localized: "Too many requests, retrying in \(UsageFormat.duration(retryAfter))")
            } else {
                String(localized: "Too many requests, retrying later")
            }
        case .network(let detail):
            String(localized: "Network: \(detail)")
        case .decoding(let detail):
            String(localized: "Unexpected response: \(detail)")
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
