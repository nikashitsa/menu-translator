import Foundation
import Observation
import OSLog
import Translation

/// Tracks which menu languages are installed for Apple Translation and asks the system to download missing ones.
///
/// Apple Translation installs languages in pairs (menu language → English) and only exposes
/// installed / not installed, so English's state is derived from the pairs. Download progress
/// is shown by the system sheet, not here.
@Observable
final class LanguageDownloads {
    enum State {
        case notDownloaded, downloaded, unsupported
    }

    /// A single tap's download request. Each one gets a new `id`, which gives the `.translationTask`
    /// a fresh identity and session — re-using one after the sheet was cancelled never shows it again.
    struct Request: Equatable {
        let id = UUID()
        let language: MenuLanguage
        let configuration: TranslationSession.Configuration
    }

    private(set) var states: [MenuLanguage.ID: State] = [:]
    private(set) var request: Request?
    /// Codes of languages seen installed, kept across launches; see `isDisconnected(_:)`.
    private var knownInstalled = Set(UserDefaults.standard.stringArray(forKey: StorageKeys.installedLanguages) ?? []) {
        didSet { UserDefaults.standard.set(Array(knownInstalled), forKey: StorageKeys.installedLanguages) }
    }

    private let target = MenuLanguage.translationTarget
    private let logger = Logger(subsystem: "com.nikashitsa.Menu-Translator", category: "LanguageDownloads")

    func state(of language: MenuLanguage) -> State {
        // The Simulator can't download languages.
        if ScreenshotMode.isEnabled { return .downloaded }
        guard language != target else { return targetState }
        return states[language.id] ?? .notDownloaded
    }

    /// The target language comes with every pair: ready once any pair is installed.
    private var targetState: State {
        MenuLanguage.menuLanguages.contains { states[$0.id] == .downloaded } ? .downloaded : .notDownloaded
    }

    /// Whether any menu language can still be downloaded (unavailable ones don't count).
    var hasMissingLanguages: Bool {
        MenuLanguage.menuLanguages.contains { state(of: $0) == .notDownloaded }
    }

    /// A language that was installed but still reports "not installed" after `refresh()`'s retries,
    /// e.g. the system's translation service (translationd) didn't come back. Downloading it again
    /// from the system sheet (`download(_:)`) restores it.
    func isDisconnected(_ language: MenuLanguage) -> Bool {
        state(of: language) == .notDownloaded && knownInstalled.contains(language.code)
    }

    /// When translationd exits (e.g. after being idle) it's restarted on the next call, but checks and
    /// translations fail as "not installed" for a second or two meanwhile. So languages installed
    /// before are re-checked a few times before they're shown as missing.
    func refresh() async {
        guard !ScreenshotMode.isEnabled else { return }
        for attempt in 1...4 {
            for language in MenuLanguage.menuLanguages {
                let state = await installedState(of: language)
                // A cancelled check fails like a missing language; keep what's known instead.
                guard !Task.isCancelled else { return }
                states[language.id] = state
            }
            let failing = MenuLanguage.menuLanguages.filter(isDisconnected)
            guard !failing.isEmpty, attempt < 4 else { return }
            logger.notice("Installed languages reported missing (\(failing.map(\.code), privacy: .public)); checking again")
            try? await Task.sleep(for: .seconds(1))
        }
    }

    func download(_ language: MenuLanguage) {
        guard language != target, state(of: language) == .notDownloaded else { return }
        request = Request(
            language: language,
            configuration: TranslationSession.Configuration(source: language.locale, target: target.locale)
        )
    }

    /// Called from `.translationTask` for `request`.
    func prepare(_ session: TranslationSession, for request: Request) async {
        // Shows the system download sheet and returns when it closes, also when cancelled.
        do {
            try await session.prepareTranslation()
        } catch {
            logger.error("\(request.language.code, privacy: .public): preparing failed: \(String(reflecting: error), privacy: .public)")
        }
        // `request` is cleared only at the end: clearing it removes the `.translationTask` running
        // this, which cancels the checks below.
        defer {
            if self.request == request {
                self.request = nil
            }
        }
        // A download restores the connection for every language, not just this one.
        await refresh()
    }

    private func installedState(of language: MenuLanguage) async -> State {
        let status = await LanguageAvailability().status(from: language.locale, to: target.locale)
        logger.debug("\(language.code, privacy: .public) → \(self.target.code, privacy: .public): \(String(describing: status), privacy: .public)")
        switch status {
        case .installed:
            knownInstalled.insert(language.code)
            return .downloaded
        case .unsupported:
            return .unsupported
        case .supported:
            // Languages installed before are double-checked: this is also reported for installed
            // pairs when the connection is lost. Others aren't, to skip a failing test translation.
            guard knownInstalled.contains(language.code), await canTranslate(from: language) else {
                return .notDownloaded
            }
            logger.notice("\(language.code, privacy: .public): reported not installed, but translating works")
            knownInstalled.insert(language.code)
            return .downloaded
        @unknown default:
            return .notDownloaded
        }
    }

    /// Ground truth for "is this pair installed": translating only works with installed languages.
    private func canTranslate(from language: MenuLanguage) async -> Bool {
        let session = TranslationSession(installedSource: language.locale, target: target.locale)
        do {
            _ = try await session.translate("menu")
            return true
        } catch {
            logger.error("\(language.code, privacy: .public): test translation failed: \(String(reflecting: error), privacy: .public)")
            return false
        }
    }
}
