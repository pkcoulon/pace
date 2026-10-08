import Foundation

struct ZaiQuotaResponse: Decodable {
    let success: Bool?
    let msg: String?
    let limits: [Limit]?
    let level: String?

    struct Limit: Decodable {
        let type: String?
        let unit: Int?
        let number: Double?
        let percentage: Double?
        let currentValue: Double?
        let usage: Double?
        let nextResetTime: Double?

        enum CodingKeys: String, CodingKey {
            case type, name, unit, number, percentage, currentValue, usage, nextResetTime
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            type = c.lenientString(forKey: .type) ?? c.lenientString(forKey: .name)
            unit = c.lenientDouble(forKey: .unit).flatMap { Int(exactly: $0) }
            number = c.lenientDouble(forKey: .number)
            percentage = c.lenientDouble(forKey: .percentage)
            currentValue = c.lenientDouble(forKey: .currentValue)
            usage = c.lenientDouble(forKey: .usage)
            nextResetTime = c.lenientDouble(forKey: .nextResetTime)
        }

        var windowSeconds: TimeInterval? {
            guard let unit, let number, number > 0 else { return nil }
            switch unit {
            case 3: return number * 3600
            case 6: return number * 7 * 86400
            default: return nil
            }
        }

        var usedPercent: Double? {
            if let usage, usage > 0, let currentValue { return max(0, currentValue / usage * 100) }
            return percentage.map { max(0, $0) }
        }

        var resetDate: Date? {
            nextResetTime.map { Date(timeIntervalSince1970: $0 / 1000) }
        }
    }

    enum CodingKeys: String, CodingKey { case success, msg, data }
    enum DataKeys: String, CodingKey { case limits, level }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = c.lenientBool(forKey: .success)
        msg = c.lenientString(forKey: .msg)
        let data = try? c.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
        limits = try? data?.decodeIfPresent([Limit].self, forKey: .limits)
        level = data?.lenientString(forKey: .level)
    }

    var isNoCodingPlan: Bool {
        success == false && (msg ?? "").lowercased().contains("coding plan")
    }

    func mapped(now: Date = Date()) -> (short: UsageWindow?, long: UsageWindow?, models: [ModelUsage]) {
        let limits = limits ?? []
        let windows = limits
            .filter { $0.type == "CREDIT_LIMIT" || $0.type == "TOKENS_LIMIT" }
            .compactMap { limit -> UsageWindow? in
                guard let seconds = limit.windowSeconds, let used = limit.usedPercent else { return nil }
                let reset = limit.resetDate.flatMap { $0 <= now.addingTimeInterval(seconds + 60) ? $0 : nil }
                return UsageWindow(utilization: used, resetsAt: reset, windowSeconds: seconds)
            }
        func slot(_ window: UsageWindow) -> WindowSlot {
            window.windowSeconds.map(WindowSlot.init(windowSeconds:)) ?? .long
        }
        let tools = limits.first { $0.type == "TIME_LIMIT" }.flatMap { limit -> ModelUsage? in
            limit.usedPercent.map {
                ModelUsage(name: String(localized: "MCP tools"), window: UsageWindow(utilization: $0, resetsAt: limit.resetDate, windowSeconds: 30 * 86400))
            }
        }
        return (windows.first { slot($0) == .short }, windows.first { slot($0) == .long }, tools.map { [$0] } ?? [])
    }
}
