import SwiftUI

struct UsageSparkline: View {
    let provider: ProviderDescriptor
    let window: UsageWindow
    @ObservedObject var history: UsageHistory

    var body: some View {
        if let end = window.resetsAt, let seconds = window.windowSeconds, seconds > 0 {
            let start = end.addingTimeInterval(-seconds)
            let samples = history.samples(for: provider.id, slot: .short, matching: window).filter { $0.date >= start }
            if samples.count >= 3, let first = samples.first, let last = samples.last {
                Sparkline(samples: samples, start: start, end: end, tint: provider.accent)
                    .help("\(window.label) window usage since the start of the cycle. Dotted line: steady pace until the reset.")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(window.label) window trend")
                    .accessibilityValue("From \(UsageFormat.percent(first.utilization)) to \(UsageFormat.percent(last.utilization))")
            }
        }
    }
}
