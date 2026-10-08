import SwiftUI

struct MenuBarSettingsTab: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        Form {
            Section {
                MenuBarPreview()
                Picker("Style", selection: $settings.menuBarStyle) {
                    ForEach(MenuBarStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Preview")
            } footer: {
                Text(description(of: settings.menuBarStyle))
            }

            Section("Display") {
                Toggle(isOn: $settings.highlightOnlyAlerts) {
                    Text("Color alerts only")
                    Text("In the menu bar and the popover: neutral values while all is well, orange then red near the limit.")
                }
                Toggle(isOn: $settings.showCountdownInMenuBar) {
                    Text("Countdown at the limit")
                    Text("At 100%, shows the time until the reset (↻23m) instead of the percentage.")
                }
            }

            Section("Displayed window") {
                let providers = settings.enabledProviders.compactMap(ProviderRegistry.descriptor(for:))
                if providers.isEmpty {
                    Text("No active connector.")
                        .foregroundStyle(.secondary)
                }
                ForEach(providers) { provider in
                    windowRow(for: provider)
                }
            }
        }
        .settingsPane()
    }

    @ViewBuilder
    private func windowRow(for provider: ProviderDescriptor) -> some View {
        let usage = store.states[provider.id]?.usage
        let windows = [usage?.shortWindow, usage?.longWindow].compactMap { $0 }
        if usage != nil, windows.count == 1, let only = windows.first {
            LabeledContent {
                Text(only.label)
                    .foregroundStyle(.secondary)
            } label: {
                connectorLabel(provider)
            }
        } else {
            Picker(selection: Binding(
                get: { settings.bar(for: provider.id) },
                set: { settings.setBar($0, for: provider.id) }
            )) {
                ForEach(BarWindow.allCases) { bar in
                    Text(label(of: bar, usage: usage)).tag(bar)
                }
            } label: {
                connectorLabel(provider)
            }
        }
    }

    private func connectorLabel(_ provider: ProviderDescriptor) -> some View {
        HStack(spacing: 8) {
            ProviderMonogram(provider: provider, size: 20)
            Text(provider.displayName)
        }
    }

    private func label(of bar: BarWindow, usage: ProviderUsage?) -> String {
        switch bar {
        case .short: usage?.shortWindow?.label ?? bar.label
        case .long: usage?.longWindow?.label ?? bar.label
        case .both: bar.label
        }
    }

    private func description(of style: MenuBarStyle) -> LocalizedStringKey {
        switch style {
        case .text: "The percentage of each window, connector by connector."
        case .rings: "One ring per connector: the outer one for the short window, the inner one for the long window."
        case .compact: "Only the highest value, with its connector's letter."
        }
    }
}

private struct MenuBarPreview: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(spacing: 8) {
                strip(dark: false, now: context.date)
                strip(dark: true, now: context.date)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(MenuBarComposer.accessibilityLabel(
                MenuBarComposer.items(store: store, settings: settings, now: context.date)
            ))
        }
    }

    private func strip(dark: Bool, now: Date) -> some View {
        HStack(spacing: 14) {
            Spacer(minLength: 0)
            Image(nsImage: MenuBarRenderer.image(store: store, settings: settings, now: now, dark: dark))
            Text(now, format: .dateTime.weekday(.abbreviated).hour().minute())
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 12)
        .frame(height: 26)
        .foregroundStyle(dark ? Color.white.opacity(0.92) : Color.black.opacity(0.85))
        .background(dark ? Color(white: 0.16) : Color(white: 0.94), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .environment(\.colorScheme, dark ? .dark : .light)
    }
}
