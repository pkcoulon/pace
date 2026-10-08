import Foundation

enum UsageFormat {
    static func percent(_ value: Double) -> String {
        (value.rounded() / 100).formatted(.percent.precision(.fractionLength(0)))
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((min(max(0, seconds), 366 * 86_400) / 60).rounded(.up))
        let hours = minutes / 60
        let rest = minutes % 60
        if hours >= 24 {
            let days = hours / 24
            let restHours = hours % 24
            return restHours > 0 ? String(localized: "\(days)d \(restHours)h") : String(localized: "\(days)d")
        }
        if hours > 0 {
            return rest > 0 ? String(localized: "\(hours)h \(String(format: "%02d", rest))") : String(localized: "\(hours)h")
        }
        return String(localized: "\(max(minutes, 1)) min")
    }

    static func countdown(to date: Date, from now: Date) -> String {
        let remaining = date.timeIntervalSince(now)
        return remaining > 0 ? String(localized: "resets in \(duration(remaining))") : String(localized: "reset")
    }

    static func resetDate(_ date: Date) -> String {
        String(localized: "resets \(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))")
    }

    static func relative(_ date: Date, now: Date) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return String(localized: "just now") }
        return String(localized: "\(duration(seconds)) ago")
    }
}
