import Foundation

enum UsageFormat {
    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))\u{202F}%"
    }

    static func barPercent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((max(0, seconds) / 60).rounded(.up))
        let hours = minutes / 60
        let rest = minutes % 60
        if hours > 0 {
            return rest > 0 ? "\(hours) h \(String(format: "%02d", rest))" : "\(hours) h"
        }
        return "\(max(minutes, 1)) min"
    }

    static func countdown(to date: Date, from now: Date) -> String {
        "réinit. dans \(duration(date.timeIntervalSince(now)))"
    }

    static func resetDate(_ date: Date) -> String {
        "réinit. " + date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
    }

    static func relative(_ date: Date, now: Date) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "à l'instant" }
        return "il y a \(duration(seconds))"
    }
}
