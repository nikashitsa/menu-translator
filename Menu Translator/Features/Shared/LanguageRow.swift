import SwiftUI

struct LanguageRow<Accessory: View>: View {
    let language: MenuLanguage
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(language.name)
                    .setFontStyle(Fonts.textLgBold)
                Text(language.details)
                    .setFontStyleMultiline(Fonts.textMd)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            accessory
                .font(.system(size: 20))
                .foregroundStyle(Colors.primary)
                .frame(width: 24, height: 24)
        }
        .foregroundStyle(Colors.text)
        .card()
    }
}

extension LanguageRow where Accessory == Image {
    init(language: MenuLanguage, systemImage: String) {
        self.language = language
        self.accessory = Image(systemName: systemImage)
    }
}
