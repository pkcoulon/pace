import Foundation

/// Réponse de GET /backend-api/wham/usage. Décodage tolérant par champ.
struct CodexUsageResponse: Decodable {
    let planType: String?
    let rateLimit: RateLimit?
    let credits: Credits?

    struct RateLimit: Decodable {
        let primaryWindow: Window?
        let secondaryWindow: Window?
        enum CodingKeys: String, CodingKey {
            case primaryWindow = "primary_window"
            case secondaryWindow = "secondary_window"
        }
    }

    struct Window: Decodable {
        let usedPercent: Double
        let limitWindowSeconds: Int?
        let resetAfterSeconds: Int?
        let resetAt: Int?
        enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case limitWindowSeconds = "limit_window_seconds"
            case resetAfterSeconds = "reset_after_seconds"
            case resetAt = "reset_at"
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if let d = try? c.decodeIfPresent(Double.self, forKey: .usedPercent) {
                usedPercent = d
            } else if let i = try? c.decodeIfPresent(Int.self, forKey: .usedPercent) {
                usedPercent = Double(i)
            } else {
                usedPercent = 0
            }
            limitWindowSeconds = try? c.decodeIfPresent(Int.self, forKey: .limitWindowSeconds)
            resetAfterSeconds = try? c.decodeIfPresent(Int.self, forKey: .resetAfterSeconds)
            resetAt = try? c.decodeIfPresent(Int.self, forKey: .resetAt)
        }
        var windowMinutes: Int? { limitWindowSeconds.map { $0 / 60 } }
        func resetDate(now: Date = Date()) -> Date? {
            if let resetAt { return Date(timeIntervalSince1970: TimeInterval(resetAt)) }
            if let resetAfterSeconds { return now.addingTimeInterval(TimeInterval(resetAfterSeconds)) }
            return nil
        }
    }

    struct Credits: Decodable {
        let hasCredits: Bool
        let unlimited: Bool
        let balance: Double?
        enum CodingKeys: String, CodingKey {
            case hasCredits = "has_credits"
            case unlimited
            case balance
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            hasCredits = (try? c.decodeIfPresent(Bool.self, forKey: .hasCredits)) ?? false
            unlimited = (try? c.decodeIfPresent(Bool.self, forKey: .unlimited)) ?? false
            if let d = try? c.decodeIfPresent(Double.self, forKey: .balance) {
                balance = d
            } else if let s = try? c.decodeIfPresent(String.self, forKey: .balance) {
                balance = Double(s)
            } else {
                balance = nil
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case rateLimit = "rate_limit"
        case credits
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        planType = try? c.decodeIfPresent(String.self, forKey: .planType)
        rateLimit = try? c.decodeIfPresent(RateLimit.self, forKey: .rateLimit)
        credits = try? c.decodeIfPresent(Credits.self, forKey: .credits)
    }

    /// Classe les fenêtres par durée réelle (18000 s = 5 h, 604800 s = 7 j), pas par
    /// position dans le JSON : sur certains plans la 5 h n'existe pas et l'hebdo
    /// occupe le slot `primary_window`.
    func mapped() -> (five: UsageWindow?, weekly: UsageWindow?) {
        let windows = [rateLimit?.primaryWindow, rateLimit?.secondaryWindow].compactMap { $0 }
        func isFiveHour(_ w: Window) -> Bool {
            guard let seconds = w.limitWindowSeconds else { return false }
            return abs(seconds - 18_000) < abs(seconds - 604_800)
        }
        func window(_ w: Window?) -> UsageWindow? {
            guard let w else { return nil }
            return UsageWindow(utilization: w.usedPercent, resetsAt: w.resetDate())
        }
        let five = window(windows.first(where: isFiveHour))
        let weekly = window(windows.first(where: { !isFiveHour($0) }))
        return (five, weekly)
    }

    func extra() -> ExtraUsage? {
        guard let c = credits else { return nil }
        let balance = c.balance ?? 0
        guard c.hasCredits || c.unlimited || balance > 0 else { return nil }
        let detail = c.unlimited ? "illimités" : Money.format(balance, currency: "USD")
        return ExtraUsage(label: "Crédits", detail: detail, fraction: nil)
    }
}
