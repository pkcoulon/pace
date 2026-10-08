import AppKit
import SwiftUI

/// Exporte le rendu réel de l'app en PNG (`Pace --snapshot <dossier>`).
/// Sert à produire des captures sans passer par la barre de menu.
@MainActor
enum SnapshotExporter {
    static var requestedDirectory: URL? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--snapshot"), index + 1 < arguments.count else { return nil }
        return URL(fileURLWithPath: arguments[index + 1])
    }

    static func export(to directory: URL, store: UsageStore, settings: SettingsStore) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let now = Date()
        for dark in [false, true] {
            let appearance = dark ? "dark" : "light"
            let label = MenuBarRenderer.image(store: store, settings: settings, now: now, dark: dark)
            write(onMenuBar(label, dark: dark), to: directory.appendingPathComponent("menubar-\(appearance).png"))
            for style in MenuBarStyle.allCases {
                let image = MenuBarRenderer.image(store: store, settings: settings, now: now, dark: dark, style: style)
                write(onMenuBar(image, dark: dark), to: directory.appendingPathComponent("menubar-\(style.rawValue)-\(appearance).png"))
            }
        }

        for dark in [false, true] {
            NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            let popover = PopoverView()
                .environmentObject(store)
                .environmentObject(settings)
                .environment(\.isSnapshot, true)
                .environment(\.colorScheme, dark ? .dark : .light)
                .background(Color(white: dark ? 0.14 : 0.94))
            let renderer = ImageRenderer(content: popover)
            renderer.scale = 2
            if let image = renderer.nsImage {
                write(image, to: directory.appendingPathComponent("popover-\(dark ? "dark" : "light").png"))
            }
        }
    }

    private static func onMenuBar(_ image: NSImage, dark: Bool) -> NSImage {
        let padding: CGFloat = 12
        let size = NSSize(width: image.size.width + padding * 2, height: 24)
        return NSImage(size: size, flipped: false) { rect in
            (dark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.93, alpha: 1)).setFill()
            rect.fill()
            image.draw(in: NSRect(x: padding, y: (rect.height - image.size.height) / 2, width: image.size.width, height: image.size.height))
            return true
        }
    }

    private static func write(_ image: NSImage, to url: URL) {
        let scale: CGFloat = 2
        let size = image.size
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * scale),
            pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }
}
