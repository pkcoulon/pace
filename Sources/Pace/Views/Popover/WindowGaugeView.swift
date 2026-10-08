import SwiftUI

struct WindowGaugeView: View {
    enum Layout {
        case column
        case row
    }

    let provider: ProviderID
    let slot: WindowSlot
    let raw: UsageWindow
    let now: Date
    var layout: Layout = .column

    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: SettingsStore

    private var window: UsageWindow { raw.effective(at: now) }
    private var expired: Bool { raw.isExpired(at: now) }
    private var level: UsageLevel { UsageLevel(percent: window.utilization) }
    private var tint: Color { Theme.color(for: level, highlightOnlyAlerts: settings.highlightOnlyAlerts) }

    private var pacing: Pacing? {
        settings.showPacing ? store.pacing(for: provider, slot: slot, now: now) : nil
    }

    private var marker: Double? {
        guard settings.showPacing, !expired,
              let reset = window.resetsAt,
              let seconds = window.windowSeconds, seconds > 0 else { return nil }
        return min(max(1 - reset.timeIntervalSince(now) / seconds, 0), 1)
    }

    var body: some View {
        Group {
            switch layout {
            case .column:
                VStack(spacing: Theme.Spacing.s) {
                    gauge(caption: window.label)
                    lines(alignment: .center)
                }
            case .row:
                HStack(spacing: Theme.Spacing.l) {
                    gauge(caption: nil)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(window.label)
                            .font(.callout.weight(.semibold))
                        lines(alignment: .leading)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((window.windowSeconds ?? 0) > 0 ? String(localized: "\(window.label) window") : window.label)
        .accessibilityValue(accessibilityValue)
    }

    private func gauge(caption: String?) -> some View {
        RingGauge(
            fraction: window.utilization / 100,
            tint: tint,
            marker: marker,
            aheadTint: level == .ok ? .orange : nil
        ) {
            GaugeValue(percent: Int(window.utilization.rounded()), caption: caption, tint: tint)
        }
    }

    private func lines(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            if let reset = resetText {
                InfoLine(icon: "arrow.clockwise", text: reset)
                    .foregroundStyle(.secondary)
                    .help(expired ? reset : window.resetsAt.map(UsageFormat.resetDate) ?? reset)
            }
            if let pacing {
                InfoLine(icon: pacing.icon, text: pacing.summary)
                    .foregroundStyle(pacing.color)
                    .fontWeight(pacing.level == .tight ? .medium : .regular)
                    .help(pacing.message)
            }
        }
        .font(.caption)
        .lineLimit(1)
    }

    private var resetText: String? {
        if expired { return String(localized: "Reset") }
        guard let date = window.resetsAt else { return nil }
        let remaining = date.timeIntervalSince(now)
        if remaining < 86400 { return UsageFormat.duration(remaining) }
        if remaining < 6 * 86400 { return date.formatted(.dateTime.weekday(.abbreviated).hour().minute()) }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    private var resetDetail: String? {
        if expired { return String(localized: "Reset, waiting for new data") }
        guard let date = window.resetsAt else { return nil }
        return date.timeIntervalSince(now) < 86400 ? UsageFormat.countdown(to: date, from: now) : UsageFormat.resetDate(date)
    }

    private var accessibilityValue: String {
        [UsageFormat.percent(window.utilization), resetDetail, pacing?.message]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

private struct GaugeValue: View {
    let percent: Int
    let caption: String?
    let tint: Color

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(percent, format: .number)
                    .font(Theme.number(size: 17))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText(value: Double(percent)))
                Text(verbatim: "%")
                    .font(Theme.number(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            if let caption {
                Text(caption)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .animation(Theme.smooth, value: percent)
    }
}

private struct InfoLine: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .imageScale(.small)
            Text(text)
                .monospacedDigit()
        }
    }
}
