import SwiftUI

struct UsageBar: View {
    let fraction: Double
    let tint: Color
    var height: CGFloat = Theme.Size.bar

    var body: some View {
        Capsule()
            .fill(.quaternary)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    let value = min(max(fraction, 0), 1)
                    Capsule()
                        .fill(tint)
                        .frame(width: value > 0 ? max(height, geometry.size.width * value) : 0)
                }
            }
            .frame(height: height)
            .animation(Theme.smooth, value: fraction)
    }
}
