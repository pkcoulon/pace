import SwiftUI

struct RingGauge<Center: View>: View {
    var fraction: Double
    var tint: Color
    var marker: Double? = nil
    var aheadTint: Color? = nil
    var size: CGFloat = Theme.Size.gauge
    var lineWidth: CGFloat = Theme.Size.gaugeStroke
    @ViewBuilder var center: Center

    private var value: Double { min(max(fraction, 0), 1) }
    private var split: Double {
        guard aheadTint != nil, let marker else { return value }
        return min(value, max(marker, 0))
    }
    private var radius: CGFloat { (size - lineWidth) / 2 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)
            if split > 0 {
                arc(from: 0, to: split, color: tint)
            }
            if value > split {
                arc(from: split, to: value, color: aheadTint ?? tint)
            }
            if let marker {
                tick(at: min(max(marker, 0), 1))
            }
            center
                .padding(lineWidth)
        }
        .padding(lineWidth / 2)
        .frame(width: size, height: size)
        .compositingGroup()
        .animation(Theme.smooth, value: fraction)
        .animation(Theme.smooth, value: marker)
    }

    private func arc(from start: Double, to end: Double, color: Color) -> some View {
        Circle()
            .trim(from: start, to: end)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }

    private func tick(at position: Double) -> some View {
        ZStack {
            Rectangle()
                .frame(width: 4, height: lineWidth)
                .blendMode(.destinationOut)
            Capsule()
                .fill(Color.primary)
                .frame(width: 2, height: lineWidth + 4)
        }
        .offset(y: -radius)
        .rotationEffect(.degrees(position * 360))
    }
}
