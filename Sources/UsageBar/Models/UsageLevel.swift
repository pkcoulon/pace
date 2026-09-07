import AppKit
import SwiftUI

enum UsageLevel: Sendable {
    case ok
    case warning
    case critical
    case unavailable

    init(percent: Double?) {
        guard let percent else {
            self = .unavailable
            return
        }
        switch percent {
        case ..<60: self = .ok
        case ...85: self = .warning
        default: self = .critical
        }
    }

    var color: Color {
        switch self {
        case .ok: .green
        case .warning: .orange
        case .critical: .red
        case .unavailable: .secondary
        }
    }

    var nsColor: NSColor {
        switch self {
        case .ok: .systemGreen
        case .warning: .systemOrange
        case .critical: .systemRed
        case .unavailable: .systemGray
        }
    }
}
