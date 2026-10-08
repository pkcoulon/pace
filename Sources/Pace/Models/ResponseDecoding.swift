import Foundation

extension KeyedDecodingContainer {
    func lenientDouble(forKey key: Key) -> Double? {
        let value = (try? decodeIfPresent(Double.self, forKey: key))
            ?? (try? decodeIfPresent(String.self, forKey: key)).flatMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        return value.flatMap { $0.isFinite ? $0 : nil }
    }

    func lenientBool(forKey key: Key) -> Bool? {
        try? decodeIfPresent(Bool.self, forKey: key)
    }

    func lenientString(forKey key: Key) -> String? {
        guard let text = try? decodeIfPresent(String.self, forKey: key) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum UTCCalendar {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.firstWeekday = 2
        return calendar
    }()

    static func monthSeconds(endingAt end: Date) -> TimeInterval {
        guard let start = calendar.date(byAdding: .month, value: -1, to: end) else { return 30 * 86400 }
        return end.timeIntervalSince(start)
    }
}
