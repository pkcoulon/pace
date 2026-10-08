import Foundation

private enum OpenRouterEnvelope: String, CodingKey { case data }

struct OpenRouterKeyResponse: Decodable {
    let limit: Double?
    let limitRemaining: Double?
    let limitReset: String?
    let usage: Double?
    let usageDaily: Double?
    let usageWeekly: Double?
    let usageMonthly: Double?
    let isFreeTier: Bool?

    enum CodingKeys: String, CodingKey {
        case limit, usage
        case limitRemaining = "limit_remaining"
        case limitReset = "limit_reset"
        case usageDaily = "usage_daily"
        case usageWeekly = "usage_weekly"
        case usageMonthly = "usage_monthly"
        case isFreeTier = "is_free_tier"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: OpenRouterEnvelope.self).nestedContainer(keyedBy: CodingKeys.self, forKey: .data)
        limit = c.lenientDouble(forKey: .limit)
        limitRemaining = c.lenientDouble(forKey: .limitRemaining)
        limitReset = c.lenientString(forKey: .limitReset)?.lowercased()
        usage = c.lenientDouble(forKey: .usage)
        usageDaily = c.lenientDouble(forKey: .usageDaily)
        usageWeekly = c.lenientDouble(forKey: .usageWeekly)
        usageMonthly = c.lenientDouble(forKey: .usageMonthly)
        isFreeTier = c.lenientBool(forKey: .isFreeTier)
    }

    var plan: String? {
        isFreeTier.map { $0 ? "Free" : "Pay as you go" }
    }

    func window(now: Date = Date()) -> UsageWindow? {
        guard let limit, limit > 0 else { return nil }
        let period: (component: Calendar.Component, usage: Double?)? = switch limitReset {
        case "daily": (.day, usageDaily)
        case "weekly": (.weekOfYear, usageWeekly)
        case "monthly": (.month, usageMonthly)
        default: nil
        }
        let used = limitRemaining.map { limit - min(limit, max(0, $0)) } ?? period?.usage ?? usage ?? 0
        let interval = period.flatMap { UTCCalendar.calendar.dateInterval(of: $0.component, for: now) }
        return UsageWindow(utilization: max(0, used) / limit * 100, resetsAt: interval?.end, windowSeconds: interval?.duration)
    }
}

struct OpenRouterCreditsResponse: Decodable {
    let totalCredits: Double?
    let totalUsage: Double?

    enum CodingKeys: String, CodingKey {
        case totalCredits = "total_credits"
        case totalUsage = "total_usage"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: OpenRouterEnvelope.self).nestedContainer(keyedBy: CodingKeys.self, forKey: .data)
        totalCredits = c.lenientDouble(forKey: .totalCredits)
        totalUsage = c.lenientDouble(forKey: .totalUsage)
    }

    func extra() -> ExtraUsage? {
        guard let totalUsage else { return nil }
        let balance = max(0, (totalCredits ?? 0) - max(0, totalUsage))
        return ExtraUsage(label: String(localized: "Credits"), detail: Money.format(balance, currency: "USD"), fraction: nil)
    }
}
