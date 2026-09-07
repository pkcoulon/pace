import AppKit
import SwiftUI

struct MenuBarValue: Equatable {
    var text: String
    var level: UsageLevel
}

struct MenuBarItem: Equatable {
    var glyph: String
    var fiveHour: MenuBarValue
    var weekly: MenuBarValue?
}

@MainActor
enum MenuBarComposer {
    static func items(states: [ProviderKind: ProviderState], settings: SettingsStore) -> [MenuBarItem] {
        settings.enabledProviders.map { kind in
            let state = states[kind] ?? .idle
            let grayed = state.error?.isAuthFailure ?? false
            let usage = state.usage
            // Certains plans Codex n'ont pas de fenêtre 5 h : on affiche alors l'hebdo
            // comme valeur principale, jamais un tiret suivi d'un pourcentage.
            let primary = usage?.fiveHour ?? usage?.weekly
            let secondary: UsageWindow? = usage?.fiveHour != nil ? usage?.weekly : nil
            return MenuBarItem(
                glyph: kind.glyph,
                fiveHour: value(primary, grayed: grayed),
                weekly: settings.menuBarMode == .fiveHourAndWeekly ? secondary.map { value($0, grayed: grayed) } : nil
            )
        }
    }

    private static func value(_ window: UsageWindow?, grayed: Bool) -> MenuBarValue {
        guard let window else { return MenuBarValue(text: "—", level: .unavailable) }
        return MenuBarValue(
            text: UsageFormat.barPercent(window.utilization),
            level: grayed ? .unavailable : UsageLevel(percent: window.utilization)
        )
    }
}

@MainActor
enum MenuBarRenderer {
    private static let glyphFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
    private static let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    private static let neutral = NSColor(white: 0.6, alpha: 1)

    static func image(for items: [MenuBarItem]) -> NSImage {
        let text = NSMutableAttributedString()
        func append(_ string: String, font: NSFont, color: NSColor) {
            text.append(NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color]))
        }

        if items.isEmpty {
            append("UB", font: glyphFont, color: neutral)
        }
        for (index, item) in items.enumerated() {
            if index > 0 { append("   ", font: valueFont, color: neutral) }
            append(item.glyph + " ", font: glyphFont, color: neutral)
            append(item.fiveHour.text, font: valueFont, color: item.fiveHour.level.nsColor)
            if let weekly = item.weekly {
                append(" · ", font: valueFont, color: neutral)
                append(weekly.text, font: valueFont, color: weekly.level.nsColor)
            }
        }

        let textSize = text.size()
        let size = NSSize(width: ceil(textSize.width), height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            text.draw(at: NSPoint(x: 0, y: (rect.height - textSize.height) / 2))
            return true
        }
        image.isTemplate = false
        return image
    }
}

struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Image(nsImage: MenuBarRenderer.image(for: MenuBarComposer.items(states: store.states, settings: settings)))
    }
}
