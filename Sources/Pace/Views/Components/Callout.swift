import SwiftUI

struct Callout: View {
    let icon: String
    let text: AttributedString
    let tint: Color

    init(icon: String, text: String, tint: Color, markdown: Bool = false) {
        self.icon = icon
        self.text = markdown ? AttributedString(inlineMarkdownWithoutLinks: text) : AttributedString(text)
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

extension AttributedString {
    init(inlineMarkdownWithoutLinks text: String) {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        var parsed = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
        for range in parsed.runs.filter({ $0.link != nil }).map(\.range) {
            parsed[range].link = nil
        }
        self = parsed
    }
}
