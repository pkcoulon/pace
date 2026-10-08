import AppKit

@MainActor
enum MenuBarRenderer {
    nonisolated static let height: CGFloat = 18
    nonisolated private static let dimmedAlpha: CGFloat = 0.45

    private static let valueFont = rounded(.monospacedDigitSystemFont(ofSize: 12, weight: .semibold))
    private static let unitFont = rounded(.systemFont(ofSize: 9, weight: .semibold))
    private static let glyphFont = rounded(.systemFont(ofSize: 10, weight: .bold))
    private static let ringGlyphFont = rounded(.systemFont(ofSize: 9, weight: .bold))
    private static let arrowFont = NSFont.systemFont(ofSize: 10, weight: .semibold)

    static func image(store: UsageStore, settings: SettingsStore, now: Date, dark: Bool, style: MenuBarStyle? = nil) -> NSImage {
        image(
            for: MenuBarComposer.items(store: store, settings: settings, now: now),
            style: style ?? settings.menuBarStyle,
            highlightOnlyAlerts: settings.highlightOnlyAlerts,
            dark: dark
        )
    }

    static func image(for items: [MenuBarItem], style: MenuBarStyle, highlightOnlyAlerts: Bool, dark: Bool) -> NSImage {
        let palette = Palette(dark: dark, highlightOnlyAlerts: highlightOnlyAlerts)
        let groups: [Group]
        switch style {
        case .text:
            groups = items.map { item in
                Group(item: item, spacing: 10, pieces: [
                    .text(glyph(item.glyph, font: glyphFont, palette: palette), font: glyphFont),
                    .gap(3),
                    .text(values(item.values, palette: palette), font: valueFont),
                ])
            }
        case .rings:
            groups = items.map { item in
                var pieces: [Piece] = [
                    .text(glyph(item.glyph, font: ringGlyphFont, palette: palette), font: ringGlyphFont),
                    .gap(3),
                    .rings(item.values.map { Ring(fraction: $0.fraction, color: palette.color($0.level), track: palette.track) }),
                ]
                if let blocked = item.values.first(where: { $0.countdown != nil }) {
                    pieces += [.gap(3), .text(values([blocked], palette: palette), font: valueFont)]
                }
                return Group(item: item, spacing: 8, pieces: pieces)
            }
        case .compact:
            groups = MenuBarComposer.worst(in: items).map { worst in
                [Group(item: worst.item, spacing: 0, pieces: [
                    .text(glyph(worst.item.glyph, font: glyphFont, palette: palette), font: glyphFont),
                    .gap(3),
                    .text(values([worst.value], palette: palette), font: valueFont),
                ])]
            } ?? []
        }
        guard !groups.isEmpty else { return emptyImage }
        return render(groups, dark: dark)
    }

    private static var emptyImage: NSImage {
        let symbol = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: "Pace")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .medium))
        let image = symbol ?? NSImage(size: NSSize(width: Theme.Size.menuBarRing, height: height))
        image.isTemplate = true
        return image
    }

    private static func glyph(_ glyph: String, font: NSFont, palette: Palette) -> NSAttributedString {
        NSAttributedString(string: glyph, attributes: [.font: font, .foregroundColor: palette.secondary])
    }

    private static func values(_ values: [MenuBarValue], palette: Palette) -> NSAttributedString {
        let text = NSMutableAttributedString()
        func append(_ string: String, _ font: NSFont, _ color: NSColor) {
            text.append(NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color]))
        }
        for (index, value) in values.enumerated() {
            if index > 0 { append(" · ", valueFont, palette.tertiary) }
            let color = palette.color(value.level)
            if let countdown = value.countdown {
                append("↻", arrowFont, color)
                append(countdown, valueFont, color)
            } else if let percent = value.percent {
                append("\(Int(percent.rounded()))", valueFont, color)
                append("%", unitFont, color.withAlphaComponent(0.6))
            } else {
                append("—", valueFont, palette.tertiary)
            }
        }
        return text
    }

    private static func rounded(_ font: NSFont) -> NSFont {
        font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: font.pointSize) } ?? font
    }

    private nonisolated static func render(_ groups: [Group], dark: Bool) -> NSImage {
        let spacing = groups.dropFirst().reduce(0) { $0 + $1.spacing }
        let width = max(groups.reduce(0) { $0 + $1.width } + spacing, 1)
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let draw = {
                var x: CGFloat = 0
                for (index, group) in groups.enumerated() {
                    if index > 0 { x += group.spacing }
                    let context = NSGraphicsContext.current?.cgContext
                    if group.dimmed {
                        context?.saveGState()
                        context?.setAlpha(dimmedAlpha)
                        context?.beginTransparencyLayer(auxiliaryInfo: nil)
                    }
                    for piece in group.pieces {
                        switch piece {
                        case .text(let text, let font):
                            let baseline = ((height - font.capHeight) / 2 * 2).rounded() / 2
                            text.draw(with: NSRect(x: x, y: baseline, width: piece.width + 1, height: 0), options: [], context: nil)
                        case .rings(let rings):
                            drawRings(rings, center: NSPoint(x: x + Theme.Size.menuBarRing / 2, y: height / 2))
                        case .gap:
                            break
                        }
                        x += piece.width
                    }
                    if group.dimmed {
                        context?.endTransparencyLayer()
                        context?.restoreGState()
                    }
                }
            }
            if let appearance = NSAppearance(named: dark ? .darkAqua : .aqua) {
                appearance.performAsCurrentDrawingAppearance(draw)
            } else {
                draw()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private nonisolated static func drawRings(_ rings: [Ring], center: NSPoint) {
        let outer = Theme.Size.menuBarRing / 2
        let strokes: [(radius: CGFloat, width: CGFloat)] = rings.count > 1 ? [(outer - 1, 2), (outer - 4, 2)] : [(outer - 1.5, 3)]
        for (ring, stroke) in zip(rings, strokes) {
            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: stroke.radius, startAngle: 0, endAngle: 360)
            track.lineWidth = stroke.width
            ring.track.setStroke()
            track.stroke()

            let fraction = min(max(ring.fraction, 0), 1)
            guard fraction > 0 else { continue }
            let arc = NSBezierPath()
            if fraction >= 1 {
                arc.appendArc(withCenter: center, radius: stroke.radius, startAngle: 0, endAngle: 360)
            } else {
                arc.appendArc(withCenter: center, radius: stroke.radius, startAngle: 90, endAngle: 90 - 360 * fraction, clockwise: true)
                arc.lineCapStyle = .round
            }
            arc.lineWidth = stroke.width
            ring.color.setStroke()
            arc.stroke()
        }
    }

    private struct Palette {
        let dark: Bool
        let highlightOnlyAlerts: Bool

        var primary: NSColor { NSColor(white: dark ? 1 : 0, alpha: dark ? 0.92 : 0.85) }
        var secondary: NSColor { NSColor(white: dark ? 1 : 0, alpha: 0.55) }
        var tertiary: NSColor { NSColor(white: dark ? 1 : 0, alpha: dark ? 0.35 : 0.3) }
        var track: NSColor { NSColor(white: dark ? 1 : 0, alpha: dark ? 0.25 : 0.17) }

        func color(_ level: UsageLevel) -> NSColor {
            switch level {
            case .ok where highlightOnlyAlerts: primary
            case .unavailable: secondary
            default: level.nsColor
            }
        }
    }

    private struct Ring {
        var fraction: Double
        var color: NSColor
        var track: NSColor
    }

    private enum Piece {
        case text(NSAttributedString, font: NSFont)
        case rings([Ring])
        case gap(CGFloat)

        var width: CGFloat {
            switch self {
            case .text(let text, _): ceil(text.size().width)
            case .rings: Theme.Size.menuBarRing
            case .gap(let width): width
            }
        }
    }

    private struct Group {
        var dimmed: Bool
        var spacing: CGFloat
        var pieces: [Piece]

        init(item: MenuBarItem, spacing: CGFloat, pieces: [Piece]) {
            self.dimmed = item.dimmed
            self.spacing = spacing
            self.pieces = pieces
        }

        var width: CGFloat {
            pieces.reduce(0) { $0 + $1.width }
        }
    }
}
