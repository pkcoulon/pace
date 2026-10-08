import SwiftUI

/// Compare le pourcentage déjà consommé à la fraction de temps écoulée dans la
/// fenêtre, pour dire si tu es sur un rythme tenable ou si tu vas taper la limite
/// avant le reset.
struct Pacing: Equatable, Sendable {
    enum Level: String, Sendable {
        case comfortable   // large marge
        case onTrack       // pile dans les clous
        case tight         // à ce rythme, limite atteinte avant le reset
    }

    enum Basis: String, Sendable {
        case recent
        case average
    }

    var level: Level
    var basis: Basis
    /// Position 0…1 du repère de rythme sur la barre (fraction de temps écoulée).
    var marker: Double
    /// Projection du pourcentage atteint au reset au rythme actuel (peut dépasser 100).
    var projected: Double
    /// Temps restant avant d'atteindre la limite au rythme actuel, si avant le reset.
    var timeToLimit: TimeInterval?
    var dailyBudget: Double?
    var message: String

    var color: Color {
        level == .tight ? .orange : .secondary
    }

    var icon: String {
        switch level {
        case .comfortable: "tortoise.fill"
        case .onTrack: "equal.circle.fill"
        case .tight: "hare.fill"
        }
    }

    var summary: String {
        if let timeToLimit {
            return timeToLimit > 0 ? String(localized: "Limit in ~\(UsageFormat.duration(timeToLimit))") : String(localized: "Limit reached")
        }
        if let dailyBudget {
            return String(localized: "~\(UsageFormat.percent(dailyBudget))/day")
        }
        return String(localized: "~\(UsageFormat.percent(projected)) at reset")
    }
}

enum PacingCalculator {
    /// Renvoie le rythme d'une fenêtre, ou nil si on manque d'info ou qu'il est
    /// trop tôt dans la fenêtre pour une projection fiable.
    static func evaluate(_ window: UsageWindow, recentRate: Double? = nil, now: Date = Date()) -> Pacing? {
        let window = window.effective(at: now)
        guard let reset = window.resetsAt,
              let duration = window.windowSeconds, duration > 0 else { return nil }
        let remaining = reset.timeIntervalSince(now)
        guard remaining > 0 else { return nil }
        let elapsed = duration - remaining
        guard elapsed > 0 else { return nil }

        let elapsedFraction = min(max(elapsed / duration, 0), 1)
        let used = window.utilization
        guard used >= 1 else { return nil }

        let basis: Pacing.Basis
        let ratePerSecond: Double
        if let recentRate {
            basis = .recent
            ratePerSecond = max(recentRate, 0)
        } else {
            // Trop tôt (moins de 8 % de la fenêtre) : la moyenne serait du bruit.
            guard elapsedFraction >= 0.08 else { return nil }
            basis = .average
            ratePerSecond = used / elapsed
        }

        let projected = used + ratePerSecond * remaining
        var timeToLimit: TimeInterval?
        if used >= 100 {
            timeToLimit = 0
        } else if ratePerSecond > 0 {
            let ttl = (100 - used) / ratePerSecond
            if ttl < remaining { timeToLimit = ttl }
        }

        var dailyBudget: Double?
        if WindowSlot(windowSeconds: duration) == .long {
            dailyBudget = max(100 - used, 0) / max(remaining / 86400, 1)
        }

        let level: Pacing.Level
        if timeToLimit != nil || projected > 108 {
            level = .tight
        } else if projected >= 90 {
            level = .onTrack
        } else {
            level = .comfortable
        }

        let message: String
        switch level {
        case .tight:
            if let ttl = timeToLimit {
                message = ttl > 0
                    ? String(localized: "At this pace, limit reached in ~\(UsageFormat.duration(ttl))")
                    : String(localized: "Limit reached")
            } else {
                message = String(localized: "At this pace, ~\(UsageFormat.percent(projected)) at reset")
            }
        case .onTrack:
            message = String(localized: "At the current pace, ~\(UsageFormat.percent(projected)) at reset")
        case .comfortable:
            message = String(localized: "Comfortable: ~\(UsageFormat.percent(projected)) at reset")
        }

        return Pacing(
            level: level,
            basis: basis,
            marker: elapsedFraction,
            projected: projected,
            timeToLimit: timeToLimit,
            dailyBudget: dailyBudget,
            message: message
        )
    }
}
