import Foundation
import Testing
import Translation
@testable import Menu_Translator

/// Apple Translation of real dish names into English. Only runs on a device with the menu
/// languages downloaded (in the app or Settings › Apps › Translate): the Simulator can't translate.
@Suite("Translating menus", .disabled(if: isSimulator, "Apple Translation doesn't run in the Simulator"))
struct MenuTranslationTests {
    @Test("Spanish dishes", arguments: MenuDishCase.all(language: "es"))
    func spanish(_ dishCase: MenuDishCase) async throws { try await translates(dishCase) }

    @Test("French dishes", arguments: MenuDishCase.all(language: "fr"))
    func french(_ dishCase: MenuDishCase) async throws { try await translates(dishCase) }

    @Test("Italian dishes", arguments: MenuDishCase.all(language: "it"))
    func italian(_ dishCase: MenuDishCase) async throws { try await translates(dishCase) }

    private func translates(_ dishCase: MenuDishCase) async throws {
        let target = MenuLanguage.translationTarget.locale
        let status = await LanguageAvailability().status(from: dishCase.locale, to: target)
        try #require(status == .installed, "Download \(dishCase.menu.language) → English translation first")
        let translation = await MenuReader.translate(dishCase.dish.name, from: dishCase.locale, to: target)
        let english = try #require(translation, "Translation failed for \(dishCase.dish.name)").lowercased()
        let message: Comment = "\"\(dishCase.dish.name)\" → \"\(english)\", expected one of \(dishCase.dish.english)"
        let isCorrect = dishCase.dish.english.contains { english.contains($0.lowercased()) }
        if let translationIssue = dishCase.dish.translationIssue {
            // Intermittent: translation models are updated with iOS.
            withKnownIssue(Comment(rawValue: translationIssue), isIntermittent: true) {
                #expect(isCorrect, message)
            }
        } else {
            #expect(isCorrect, message)
        }
    }
}

private let isSimulator: Bool = {
    #if targetEnvironment(simulator)
    true
    #else
    false
    #endif
}()
