import Foundation

/// Réponse de GET /api/oauth/usage (OAuth) et de /organizations/{id}/usage (session key).
/// Décodage tolérant : chaque bucket en `try?`, les clés de code inconnues ignorées.
struct ClaudeUsageResponse: Decodable {
    let fiveHour: Bucket?
    let sevenDay: Bucket?
    let sevenDayOpus: Bucket?
    let sevenDaySonnet: Bucket?
    let extraUsage: ExtraUsageDTO?
    let limits: [LimitEntry]?

    struct Bucket: Decodable {
        let utilization: Double
        let resetsAt: String?
        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
        var resetsAtDate: Date? { ISO8601.date(from: resetsAt) }
    }

    struct ExtraUsageDTO: Decodable {
        let isEnabled: Bool?
        let monthlyLimit: Double?
        let usedCredits: Double?
        let utilization: Double?
        let currency: String?
        let decimalPlaces: Int?
        enum CodingKeys: String, CodingKey {
            case isEnabled = "is_enabled"
            case monthlyLimit = "monthly_limit"
            case usedCredits = "used_credits"
            case utilization
            case currency
            case decimalPlaces = "decimal_places"
        }
    }

    struct LimitEntry: Decodable {
        let kind: String?
        let percent: Double?
        let resetsAt: String?
        let scope: Scope?
        enum CodingKeys: String, CodingKey {
            case kind, percent, scope
            case resetsAt = "resets_at"
        }
        struct Scope: Decodable {
            let model: Model?
            struct Model: Decodable {
                let displayName: String?
                enum CodingKeys: String, CodingKey { case displayName = "display_name" }
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case extraUsage = "extra_usage"
        case limits
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fiveHour = try? c.decodeIfPresent(Bucket.self, forKey: .fiveHour)
        sevenDay = try? c.decodeIfPresent(Bucket.self, forKey: .sevenDay)
        sevenDayOpus = try? c.decodeIfPresent(Bucket.self, forKey: .sevenDayOpus)
        sevenDaySonnet = try? c.decodeIfPresent(Bucket.self, forKey: .sevenDaySonnet)
        extraUsage = try? c.decodeIfPresent(ExtraUsageDTO.self, forKey: .extraUsage)
        limits = try? c.decodeIfPresent([LimitEntry].self, forKey: .limits)
    }

    var hasNoWindows: Bool {
        fiveHour == nil && sevenDay == nil && (limits?.isEmpty ?? true)
    }

    /// Lignes par modèle : d'abord les entrées `weekly_scoped` du tableau `limits`
    /// (forme actuelle), sinon les buckets `seven_day_opus` / `seven_day_sonnet`.
    func modelUsages() -> [ModelUsage] {
        let scoped = (limits ?? []).compactMap { entry -> ModelUsage? in
            guard entry.kind == "weekly_scoped",
                  let name = entry.scope?.model?.displayName else { return nil }
            return ModelUsage(name: name, window: UsageWindow(
                utilization: entry.percent ?? 0,
                resetsAt: ISO8601.date(from: entry.resetsAt)
            ))
        }
        if !scoped.isEmpty { return scoped }

        var legacy: [ModelUsage] = []
        if let opus = sevenDayOpus {
            legacy.append(ModelUsage(name: "Opus", window: UsageWindow(utilization: opus.utilization, resetsAt: opus.resetsAtDate)))
        }
        if let sonnet = sevenDaySonnet {
            legacy.append(ModelUsage(name: "Sonnet", window: UsageWindow(utilization: sonnet.utilization, resetsAt: sonnet.resetsAtDate)))
        }
        return legacy
    }

    func extra() -> ExtraUsage? {
        guard let e = extraUsage else { return nil }
        let enabled = e.isEnabled ?? false
        let used = e.usedCredits ?? 0
        guard enabled || used > 0 else { return nil }
        let decimals = e.decimalPlaces ?? 2
        let divisor = pow(10.0, Double(decimals))
        let currency = e.currency ?? "USD"
        let usedAmount = used / divisor
        let limitAmount = (e.monthlyLimit ?? 0) / divisor
        let detail = "\(Money.format(usedAmount, currency: currency)) / \(Money.format(limitAmount, currency: currency))"
        return ExtraUsage(label: "Extra usage", detail: detail, fraction: (e.utilization ?? 0) / 100)
    }
}

struct ClaudeErrorResponse: Decodable {
    let error: Detail?
    struct Detail: Decodable { let type: String? }
    var isPermissionError: Bool { error?.type == "permission_error" }
}

struct ClaudeOrganization: Decodable {
    let uuid: String
}

enum Money {
    static func format(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }
}
