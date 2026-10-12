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
    @Environment(\.isPanelOpen) private var isOpen
    @Environment(\.entranceDelay) private var entranceDelay
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hidden = false

    private var window: UsageWindow { raw.effective(at: now) }
    private var expired: Bool { raw.isExpired(at: now) }
    private var level: UsageLevel { UsageLevel(percent: window.utilization) }
    private var tint: Color { Theme.color(for: level, highlightOnlyAlerts: settings.highlightOnlyAlerts) }

    private var pacing: Pacing? {
        settings.showPacing ? store.pacing(for: provider, slot: slot, now: now) : nil
    }

    private var projection: Double? {
        guard !expired, let pacing else { return nil }
        return pacing.projected / 100
    }

    private var glow: Color? {
        guard isOpen, !expired else { return nil }
        if level == .critical { return .red }
        return pacing?.level == .tight ? .orange : nil
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
        .animation(Theme.smooth, value: window.utilization)
        .animation(Theme.smooth, value: projection)
        .onChange(of: isOpen, initial: true) { _, open in
            if open {
                withAnimation(Theme.fill.delay(entranceDelay + 0.08)) { hidden = false }
            } else if !reduceMotion {
                hidden = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((window.windowSeconds ?? 0) > 0 ? String(localized: "\(window.label) window") : window.label)
        .accessibilityValue(accessibilityValue)
    }

    private func gauge(caption: String?) -> some View {
        RingGauge(
            fraction: hidden ? 0 : window.utilization / 100,
            tint: tint,
            projection: hidden ? nil : projection,
            glow: glow
        ) {
            GaugeValue(percent: hidden ? 0 : Int(window.utilization.rounded()), caption: caption, tint: tint)
        }
        .help(projection == nil ? String() : String(localized: "Solid: used so far. Dotted: projected at reset at your current pace."))
    }

    private func lines(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            if let reset = resetText {
                InfoLine(icon: "arrow.clockwise", text: reset)
                    .foregroundStyle(.secondary)
                    .help(resetDetail ?? reset)
            }
            if let pacing {
                InfoLine(icon: pacing.icon, text: pacing.summary)
                    .foregroundStyle(pacing.color)
                    .fontWeight(pacing.level == .tight ? .semibold : .regular)
                    .help(pacing.explanation)
            }
        }
        .font(.caption)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .modifier(Entrance(delay: 0.18, offset: 4))
    }

    private var resetText: String? {
        if expired { return String(localized: "Reset") }
        guard let date = window.resetsAt else { return nil }
        let remaining = date.timeIntervalSince(now)
        if remaining < 86400 { return String(localized: "Resets in \(UsageFormat.duration(remaining))") }
        if remaining < 6 * 86400 {
            return String(localized: "Resets \(date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))")
        }
        return String(localized: "Resets \(date.formatted(.dateTime.day().month(.abbreviated)))")
    }

    private var resetDetail: String? {
        if expired { return String(localized: "Reset, waiting for new data") }
        guard let date = window.resetsAt else { return nil }
        return date.timeIntervalSince(now) < 86400 ? UsageFormat.countdown(to: date, from: now) : UsageFormat.resetDate(date)
    }

    private var accessibilityValue: String {
        [UsageFormat.percent(window.utilization), resetDetail, pacing?.explanation]
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
