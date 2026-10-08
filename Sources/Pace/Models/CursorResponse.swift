import Foundation

struct CursorUsageResponse: Decodable {
    let enabled: Bool?
    let billingCycleStart: Double?
    let billingCycleEnd: Double?
    let planUsage: PlanUsage?
    let spendLimitUsage: SpendLimitUsage?

    struct PlanUsage: Decodable {
        let limit: Double?
        let remaining: Double?
        let totalSpend: Double?
        let totalPercentUsed: Double?
        let autoPercentUsed: Double?
        let apiPercentUsed: Double?

        enum CodingKeys: String, CodingKey {
            case limit, remaining, totalSpend, totalPercentUsed, autoPercentUsed, apiPercentUsed
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            limit = c.lenientDouble(forKey: .limit)
            remaining = c.lenientDouble(forKey: .remaining)
            totalSpend = c.lenientDouble(forKey: .totalSpend)
            totalPercentUsed = c.lenientDouble(forKey: .totalPercentUsed)
            autoPercentUsed = c.lenientDouble(forKey: .autoPercentUsed)
            apiPercentUsed = c.lenientDouble(forKey: .apiPercentUsed)
        }

        var hasModelPools: Bool {
            guard let auto = autoPercentUsed, let api = apiPercentUsed, auto >= 0, api >= 0 else { return false }
            let spent = totalSpend ?? ((limit ?? 0) - (remaining ?? limit ?? 0))
            return auto > 0 || api > 0 || spent == 0
        }

        var computedPercent: Double? {
            guard let limit, limit > 0 else { return nil }
            return (totalSpend ?? (limit - (remaining ?? 0))) / limit * 100
        }
    }

    struct SpendLimitUsage: Decodable {
        let individualLimit: Double?
        let individualRemaining: Double?
        let individualUsed: Double?
        let pooledLimit: Double?
        let pooledRemaining: Double?
        let pooledUsed: Double?
        let totalSpend: Double?
        let limitType: String?

        enum CodingKeys: String, CodingKey {
            case individualLimit, individualRemaining, individualUsed
            case pooledLimit, pooledRemaining, pooledUsed, totalSpend, limitType
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            individualLimit = c.lenientDouble(forKey: .individualLimit)
            individualRemaining = c.lenientDouble(forKey: .individualRemaining)
            individualUsed = c.lenientDouble(forKey: .individualUsed)
            pooledLimit = c.lenientDouble(forKey: .pooledLimit)
            pooledRemaining = c.lenientDouble(forKey: .pooledRemaining)
            pooledUsed = c.lenientDouble(forKey: .pooledUsed)
            totalSpend = c.lenientDouble(forKey: .totalSpend)
            limitType = c.lenientString(forKey: .limitType)?.lowercased()
        }
    }

    enum CodingKeys: String, CodingKey {
        case enabled, billingCycleStart, billingCycleEnd, planUsage, spendLimitUsage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = c.lenientBool(forKey: .enabled)
        billingCycleStart = c.lenientDouble(forKey: .billingCycleStart)
        billingCycleEnd = c.lenientDouble(forKey: .billingCycleEnd)
        planUsage = try? c.decodeIfPresent(PlanUsage.self, forKey: .planUsage)
        spendLimitUsage = try? c.decodeIfPresent(SpendLimitUsage.self, forKey: .spendLimitUsage)
    }

    func mapped(planName: String?) -> (long: UsageWindow?, models: [ModelUsage])? {
        guard enabled != false, let planUsage else { return nil }
        let resetsAt = billingCycleEnd.map { Date(timeIntervalSince1970: $0 / 1000) }
        var seconds: TimeInterval = 30 * 86400
        if let start = billingCycleStart, let end = billingCycleEnd, end > start {
            seconds = (end - start) / 1000
        }
        func window(_ percent: Double) -> UsageWindow {
            UsageWindow(utilization: max(0, percent), resetsAt: resetsAt, windowSeconds: seconds)
        }
        let isTeam = planName?.lowercased() == "team"
            || spendLimitUsage?.limitType == "team"
            || (spendLimitUsage?.pooledLimit ?? 0) > 0
        let computed = isTeam && planUsage.hasModelPools ? nil : planUsage.computedPercent
        let models = [("Auto", planUsage.autoPercentUsed), ("API", planUsage.apiPercentUsed)]
            .compactMap { name, percent in percent.map { ModelUsage(name: name, window: window($0)) } }
        return ((planUsage.totalPercentUsed ?? computed).map(window), models)
    }

    func onDemand() -> ExtraUsage? {
        guard let s = spendLimitUsage else { return nil }
        let limit = s.individualLimit ?? s.pooledLimit ?? 0
        let remaining = s.individualRemaining ?? s.pooledRemaining ?? 0
        let reported = [s.individualUsed, s.pooledUsed, s.totalSpend].compactMap { $0 }
        let inferred = max(0, limit - remaining)
        let spent = reported.first { $0 > 0 } ?? (inferred > 0 ? inferred : reported.first ?? 0)
        if limit > 0 {
            let detail = "\(Money.format(spent / 100, currency: "USD")) / \(Money.format(limit / 100, currency: "USD"))"
            return ExtraUsage(label: String(localized: "On-demand"), detail: detail, fraction: spent / limit)
        }
        guard spent > 0 else { return nil }
        return ExtraUsage(label: String(localized: "On-demand"), detail: Money.format(spent / 100, currency: "USD"), fraction: nil)
    }
}

struct CursorPlanInfoResponse: Decodable {
    let planName: String?

    enum CodingKeys: String, CodingKey { case planInfo }
    enum PlanInfoKeys: String, CodingKey { case planName }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        planName = (try? c.nestedContainer(keyedBy: PlanInfoKeys.self, forKey: .planInfo))?.lenientString(forKey: .planName)
    }
}
