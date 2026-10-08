import AppKit
import SwiftUI

struct UpdateBanner: View {
    let update: AvailableUpdate

    @State private var hovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(update.url)
        } label: {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "arrow.down.circle.fill")
                Text("Pace \(update.version) is available")
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Text("View")
                    .fontWeight(.semibold)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .font(.callout)
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, 7)
            .background(Color.accentColor.opacity(hovering ? 0.2 : Theme.Opacity.tint), in: Theme.pill)
            .contentShape(Theme.pill)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
        .modifier(LinkPointer())
        .help("Open the release page for version \(update.version)")
    }
}
