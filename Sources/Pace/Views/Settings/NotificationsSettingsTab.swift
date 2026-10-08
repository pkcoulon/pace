import SwiftUI

struct NotificationsSettingsTab: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                ThresholdRow(
                    title: "Short window",
                    subtitle: "5h, day",
                    warning: $settings.shortWarning,
                    critical: $settings.shortCritical
                )
                ThresholdRow(
                    title: "Long window",
                    subtitle: "Week, month",
                    warning: $settings.longWarning,
                    critical: $settings.longCritical
                )
            } header: {
                Text("Thresholds")
            } footer: {
                Text("One notification per threshold crossed, once per cycle.")
            }

            Section("Alerts") {
                Toggle(isOn: $settings.notifyOnPace) {
                    Text("Pace alert")
                    Text("When the short window will run out in less than an hour at the current pace.")
                }
                Toggle(isOn: $settings.notifyOnReset) {
                    Text("Window reset")
                    Text("Notifies you when a window that reached the critical threshold resets.")
                }
            }
        }
        .settingsPane()
    }
}

private struct ThresholdRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @Binding var warning: Int
    @Binding var critical: Int

    var body: some View {
        LabeledContent {
            HStack(spacing: 16) {
                stepper("Warning", value: $warning, range: 50...max(50, critical - 5), tint: .orange)
                stepper("Critical", value: $critical, range: min(warning + 5, 100)...100, tint: .red)
            }
        } label: {
            Text(title)
            Text(subtitle)
        }
    }

    private func stepper(_ label: LocalizedStringKey, value: Binding<Int>, range: ClosedRange<Int>, tint: Color) -> some View {
        Stepper(value: value, in: range, step: 5) {
            HStack(spacing: 5) {
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)
                Text(label)
                    .foregroundStyle(.secondary)
                Text(UsageFormat.percent(Double(value.wrappedValue)))
                    .monospacedDigit()
            }
        }
        .fixedSize()
        .accessibilityValue(UsageFormat.percent(Double(value.wrappedValue)))
    }
}
