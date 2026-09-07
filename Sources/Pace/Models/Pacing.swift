import SwiftUI

/// Compare le pourcentage déjà consommé à la fraction de temps écoulée dans la
/// fenêtre, pour dire si tu es sur un rythme tenable ou si tu vas taper la limite
/// avant le reset.
struct Pacing: Equatable, Sendable {
    enum Level: Sendable {
        case comfortable   // large marge
        case onTrack       // pile dans les clous
        case tight         // à ce rythme, limite atteinte avant le reset
    }

    var level: Level
    /// Position 0…1 du repère de rythme sur la barre (fraction de temps écoulée).
    var marker: Double
    /// Projection du pourcentage atteint au reset au rythme actuel (peut dépasser 100).
    var projected: Double
    /// Temps restant avant d'atteindre la limite au rythme actuel, si avant le reset.
    var timeToLimit: TimeInterval?
    var message: String

    var color: Color {
        switch level {
        case .comfortable: .green
        case .onTrack: .secondary
        case .tight: .orange
        }
    }

    var icon: String {
        switch level {
        case .comfortable: "tortoise.fill"
        case .onTrack: "equal.circle.fill"
        case .tight: "hare.fill"
        }
    }
}

enum PacingCalculator {
    /// Renvoie le rythme d'une fenêtre, ou nil si on manque d'info ou qu'il est
    /// trop tôt dans la fenêtre pour une projection fiable.
    static func evaluate(_ window: UsageWindow, now: Date = Date()) -> Pacing? {
        guard let reset = window.resetsAt,
              let duration = window.windowSeconds, duration > 0 else { return nil }
        let remaining = reset.timeIntervalSince(now)
        guard remaining > 0 else { return nil }
        let elapsed = duration - remaining
        guard elapsed > 0 else { return nil }

        let elapsedFraction = min(max(elapsed / duration, 0), 1)
        let used = window.utilization

        // Trop tôt (moins de 8 % de la fenêtre) ou consommation négligeable :
        // la projection serait du bruit.
        guard elapsedFraction >= 0.08, used >= 1 else { return nil }

        let projected = used / elapsedFraction
        let ratePerSecond = used / elapsed
        var timeToLimit: TimeInterval?
        if ratePerSecond > 0 {
            let ttl = (100 - used) / ratePerSecond
            if ttl < remaining { timeToLimit = ttl }
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
                message = "À ce rythme, limite atteinte dans ~\(UsageFormat.duration(ttl))"
            } else {
                message = "À ce rythme, ~\(Int(projected.rounded())) % au reset"
            }
        case .onTrack:
            message = "Au rythme actuel, ~\(Int(projected.rounded())) % au reset"
        case .comfortable:
            message = "Large : ~\(Int(projected.rounded())) % au reset"
        }

        return Pacing(level: level, marker: elapsedFraction, projected: projected, timeToLimit: timeToLimit, message: message)
    }
}
