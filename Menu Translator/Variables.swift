import SwiftUI

struct FontStyle {
    let size: CGFloat
    let weight: Font.Weight
    let lineHeight: CGFloat
    let letterSpacing: CGFloat
}

struct Fonts {
    
    static let textXs = FontStyle(size: 12, weight: .regular, lineHeight: 1.5, letterSpacing: 0.03)
    static let textXsBold = FontStyle(size: 12, weight: .semibold, lineHeight: 1.5, letterSpacing: 0.03)
    
    static let textMd = FontStyle(size: 16, weight: .regular, lineHeight: 1.5, letterSpacing: 0.01)
    static let textMdBold = FontStyle(size: 16, weight: .semibold, lineHeight: 1.5, letterSpacing: 0.01)
    
    static let textLg = FontStyle(size: 20, weight: .regular, lineHeight: 1.35, letterSpacing: 0)
    static let textLgBold = FontStyle(size: 20, weight: .semibold, lineHeight: 1.35, letterSpacing: 0)
    
    static let textXl = FontStyle(size: 32, weight: .regular, lineHeight: 1.2, letterSpacing: -0.01)
    static let textXlBold = FontStyle(size: 32, weight: .semibold, lineHeight: 1.2, letterSpacing: -0.01)
    
    static let text2Xl = FontStyle(size: 96, weight: .regular, lineHeight: 1.2, letterSpacing: -0.02)
    static let text2XlBold = FontStyle(size: 96, weight: .semibold, lineHeight: 1.2, letterSpacing: -0.02)
}

extension Text {
    func setFontStyle(_ fontStyle: FontStyle) -> some View {
        self.font(Font.system(size: fontStyle.size, weight: fontStyle.weight))
            .kerning(fontStyle.size * fontStyle.letterSpacing)
            .frame(height: fontStyle.size * fontStyle.lineHeight)
            .lineLimit(1)
    }
    func setFontStyleMultiline(_ fontStyle: FontStyle) -> some View {
        self.font(Font.system(size: fontStyle.size, weight: fontStyle.weight))
            .kerning(fontStyle.size * fontStyle.letterSpacing)
            .lineSpacing(fontStyle.size * (fontStyle.lineHeight - 1))
    }
}

struct Colors {
    static let text = Color("Text")
    static let black = Color("Black")
    static let white = Color("White")
    static let red = Color("Red")
    static let gray = Color("Gray")
    static let primary = Color("Primary")
    static let secondary = Color("Secondary")
    static let danger = Color("Danger")
}

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Colors.primary)
            .foregroundStyle(Colors.white)
            .clipShape(.capsule)
    }
}

/// `PrimaryButton` for destructive actions.
struct DangerButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Colors.danger)
            .foregroundStyle(Colors.white)
            .clipShape(.capsule)
    }
}

/// 40pt capsule button; label is expected to use `Fonts.textXsBold`.
struct SmallButton: ButtonStyle {
    enum Variant {
        case primary, secondary, dark
    }

    var variant: Variant = .secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(.capsule)
    }

    private var background: Color {
        switch variant {
        case .primary: Colors.primary
        case .secondary: Colors.secondary
        case .dark: Colors.gray
        }
    }

    private var foreground: Color {
        variant == .secondary ? Colors.text : Colors.white
    }
}

struct IconButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 40, height: 40)
            .background(Colors.gray)
            .foregroundStyle(Colors.white)
            .clipShape(.circle)
    }
}

/// 40pt circle with a primary outline, e.g. quantity −/+.
struct OutlineIconButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 40, height: 40)
            .foregroundStyle(Colors.primary)
            .overlay(Circle().strokeBorder(Colors.primary, lineWidth: 1))
            .contentShape(.circle)
    }
}

struct Card: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Colors.secondary, in: .rect(cornerRadius: 16))
    }
}

extension View {
    func card() -> some View {
        modifier(Card())
    }

    /// Strips default List row chrome so rows lay out like the app's other screens; used by Lists
    /// that need swipe-to-delete.
    func plainListRow(top: CGFloat = 0, bottom: CGFloat = 0) -> some View {
        self
            .listRowInsets(EdgeInsets(top: top, leading: 16, bottom: bottom, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
