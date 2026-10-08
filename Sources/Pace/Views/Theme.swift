import SwiftUI

enum Theme {
    enum Radius {
        static let card: CGFloat = 16
        static let tile: CGFloat = 6
        static let callout: CGFloat = 10
    }

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Inset {
        static let popover: CGFloat = 12
        static let card: CGFloat = 14
    }

    enum Size {
        static let popoverWidth: CGFloat = 340
        static let popoverContentMaxHeight: CGFloat = 580
        static let gauge: CGFloat = 64
        static let gaugeStroke: CGFloat = 7
        static let iconButton: CGFloat = 26
        static let menuBarRing: CGFloat = 16
        static let monogram: CGFloat = 24
        static let sparkline: CGFloat = 30
        static let bar: CGFloat = 4
    }

    enum Opacity {
        static let stale: Double = 0.55
        static let tint: Double = 0.14
        static let monogram: Double = 0.18
    }

    static var card: RoundedRectangle { RoundedRectangle(cornerRadius: Radius.card, style: .continuous) }
    static var tile: RoundedRectangle { RoundedRectangle(cornerRadius: Radius.tile, style: .continuous) }
    static var callout: RoundedRectangle { RoundedRectangle(cornerRadius: Radius.callout, style: .continuous) }
    static var pill: Capsule { Capsule(style: .continuous) }

    static let smooth: Animation = .smooth(duration: 0.35)
    static let hover: Animation = .easeOut(duration: 0.12)

    static func number(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    static func color(for level: UsageLevel, highlightOnlyAlerts: Bool, neutral: Color = .primary) -> Color {
        level == .ok && highlightOnlyAlerts ? neutral : level.color
    }
}
