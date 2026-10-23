import SwiftUI

/// Back arrow followed by a title, used at the top of light screens.
struct BackHeader<Title: View>: View {
    let onBack: () -> Void
    @ViewBuilder let title: Title

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .frame(width: 50, height: 50)
                    .contentShape(.rect)
            }
            title
                .font(.system(size: Fonts.textLgBold.size, weight: Fonts.textLgBold.weight))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Colors.text)
    }
}
