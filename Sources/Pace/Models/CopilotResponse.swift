import Foundation

struct CopilotUsageResponse: Decodable {
    let copilotPlan: String?
    let quotaResetDate: String?
    let limitedUserResetDate: String?
    let tokenBasedBilling: Bool?
    let quotaSnapshots: Snapshots?
    let limitedUserQuotas: Counts?
    let monthlyQuotas: Counts?

    struct Snapshots: Decodable {
        let premiumInteractions: Snapshot?
        let chat: Snapshot?
        let completions: Snapshot?
        enum CodingKeys: String, CodingKey {
            case premiumInteractions = "premium_interactions"
            case chat, completions
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            premiumInteractions = try? c.decodeIfPresent(Snapshot.self, forKey: .premiumInteractions)
            chat = try? c.decodeIfPresent(Snapshot.self, forKey: .chat)
            completions = try? c.decodeIfPresent(Snapshot.self, forKey: .completions)
        }
    }

    struct Snapshot: Decodable {
        let entitlement: Double?
        let remaining: Double?
        let percentRemaining: Double?
        let unlimited: Bool
        let overagePermitted: Bool
        let overageCount: Double?
        let creditsUsed: Double?
        enum CodingKeys: String, CodingKey {
            case entitlement, remaining, unlimited
            case percentRemaining = "percent_remaining"
            case overagePermitted = "overage_permitted"
            case overageCount = "overage_count"
            case creditsUsed = "credits_used"
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            entitlement = c.lenientDouble(forKey: .entitlement)
            remaining = c.lenientDouble(forKey: .remaining)
            percentRemaining = c.lenientDouble(forKey: .percentRemaining)
            unlimited = c.lenientBool(forKey: .unlimited) ?? false
            overagePermitted = c.lenientBool(forKey: .overagePermitted) ?? false
            overageCount = c.lenientDouble(forKey: .overageCount)
            creditsUsed = c.lenientDouble(forKey: .creditsUsed)
        }

        var usedPercent: Double? {
            guard !unlimited, entitlement != -1, remaining != -1, entitlement != 0 else { return nil }
            if let percentRemaining { return max(0, 100 - percentRemaining) }
            if let entitlement, entitlement > 0, let remaining { return max(0, 100 - remaining / entitlement * 100) }
            return nil
        }
    }

    struct Counts: Decodable {
        let chat: Double?
        let completions: Double?
        enum CodingKeys: String, CodingKey { case chat, completions }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            chat = c.lenientDouble(forKey: .chat)
            completions = c.lenientDouble(forKey: .completions)
        }
    }

    enum CodingKeys: String, CodingKey {
        case copilotPlan = "copilot_plan"
        case quotaResetDate = "quota_reset_date"
        case limitedUserResetDate = "limited_user_reset_date"
        case tokenBasedBilling = "token_based_billing"
        case quotaSnapshots = "quota_snapshots"
        case limitedUserQuotas = "limited_user_quotas"
        case monthlyQuotas = "monthly_quotas"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        copilotPlan = c.lenientString(forKey: .copilotPlan)
        quotaResetDate = c.lenientString(forKey: .quotaResetDate)
        limitedUserResetDate = c.lenientString(forKey: .limitedUserResetDate)
        tokenBasedBilling = c.lenientBool(forKey: .tokenBasedBilling)
        quotaSnapshots = try? c.decodeIfPresent(Snapshots.self, forKey: .quotaSnapshots)
        limitedUserQuotas = try? c.decodeIfPresent(Counts.self, forKey: .limitedUserQuotas)
        monthlyQuotas = try? c.decodeIfPresent(Counts.self, forKey: .monthlyQuotas)
    }

    var resetsAt: Date? {
        Self.date(quotaResetDate) ?? Self.date(limitedUserResetDate)
    }

    func mapped() -> (long: UsageWindow?, models: [ModelUsage]) {
        let resetsAt = resetsAt
        let seconds = resetsAt.map(UTCCalendar.monthSeconds(endingAt:)) ?? 30 * 86400
        func window(_ percent: Double) -> UsageWindow {
            UsageWindow(utilization: percent, resetsAt: resetsAt, windowSeconds: seconds)
        }
        let premium = quotaSnapshots?.premiumInteractions?.usedPercent.map(window)
        var models = [("Chat", quotaSnapshots?.chat), (String(localized: "Completions"), quotaSnapshots?.completions)]
            .compactMap { name, snapshot in snapshot?.usedPercent.map { ModelUsage(name: name, window: window($0)) } }
        if premium == nil, models.isEmpty {
            models = [
                ("Chat", limitedUserQuotas?.chat, monthlyQuotas?.chat),
                (String(localized: "Completions"), limitedUserQuotas?.completions, monthlyQuotas?.completions),
            ].compactMap { name, remaining, total in
                guard let total, total > 0, let remaining else { return nil }
                return ModelUsage(name: name, window: window(max(0, total - remaining) / total * 100))
            }
        }
        let long = premium ?? models.max { $0.window.utilization < $1.window.utilization }?.window
        return (long, models)
    }

    func extra() -> ExtraUsage? {
        guard let premium = quotaSnapshots?.premiumInteractions else { return nil }
        if premium.usedPercent != nil {
            guard premium.overagePermitted else { return nil }
            return ExtraUsage(label: String(localized: "Overage"), detail: Self.count(max(0, premium.overageCount ?? 0)), fraction: nil)
        }
        guard let used = premium.creditsUsed, used > 0 else { return nil }
        return ExtraUsage(label: String(localized: "Credits used"), detail: Self.count(used), fraction: nil)
    }

    private static func count(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private static func date(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return ISO8601.date(from: raw) ?? (try? Date.ISO8601FormatStyle().year().month().day().parse(raw))
    }
}
