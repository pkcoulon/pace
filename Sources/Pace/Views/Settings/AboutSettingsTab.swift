import AppKit
import SwiftUI

struct AboutSettingsTab: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.openURL) private var openURL

    private static let repository = URL(string: "https://github.com/pkcoulon/pace")!

    private var version: String {
        guard let short = UpdateChecker.currentVersion else { return String(localized: "Development version") }
        let version = String(localized: "Version \(short)")
        guard let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else { return version }
        return "\(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(verbatim: "Pace")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                Text(version)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .textSelection(.enabled)
            }

            Text("Your AI usage in the menu bar.\nNo telemetry, no dependencies.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if let update = store.availableUpdate {
                Button {
                    openURL(update.url)
                } label: {
                    Label("Pace \(update.version) is available", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            }

            HStack(spacing: 10) {
                Button {
                    openURL(Self.repository)
                } label: {
                    Label("Source code", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Button {
                    openURL(Self.repository.appendingPathComponent("issues"))
                } label: {
                    Label("Report an issue", systemImage: "ladybug")
                }
            }
            .buttonStyle(.bordered)

            Divider()
                .frame(width: 240)
                .padding(.vertical, 4)

            VStack(spacing: 6) {
                Text("Acknowledgements")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Authentication approaches studied in [TokenEater](https://github.com/AThevon/TokenEater), [Claude-Usage-Tracker](https://github.com/hamed-elfayome/Claude-Usage-Tracker), [codexbar](https://github.com/steipete/codexbar) and [usage4claude](https://github.com/f-is-h/usage4claude). Copilot, Cursor, z.ai and OpenRouter formats cross-checked with [openusage](https://github.com/robinebers/openusage), codexbar and the [z.ai plugins](https://github.com/zai-org/zai-coding-plugins).")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("© 2026 Pierrick Coulon · MIT License")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 28)
        .frame(width: 500)
    }
}
