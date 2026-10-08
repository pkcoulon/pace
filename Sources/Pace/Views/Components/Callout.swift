import SwiftUI

struct Callout: View {
    let icon: String
    let text: AttributedString
    let tint: Color

    init(icon: String, text: String, tint: Color, markdown: Bool = false) {
        self.icon = icon
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        self.text = markdown ? (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text) : AttributedString(text)
        self.tint = tint
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(text)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(Theme.Opacity.tint), in: Theme.callout)
        .accessibilityElement(children: .combine)
    }
}
