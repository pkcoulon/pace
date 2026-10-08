import SwiftUI

struct ProviderMonogram: View {
    let provider: ProviderDescriptor
    var size: CGFloat = Theme.Size.monogram

    var body: some View {
        Text(provider.glyph)
            .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
            .foregroundStyle(provider.accent)
            .frame(width: size, height: size)
            .background(provider.accent.opacity(Theme.Opacity.monogram), in: Theme.tile)
            .accessibilityHidden(true)
    }
}
