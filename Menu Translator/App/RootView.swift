import SwiftUI

struct RootView: View {
    @AppStorage(StorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @State private var router = Router()
    /// Shared so Scan can check installed languages before Translation needs them.
    @State private var downloads = LanguageDownloads()
    @State private var rates = ExchangeRates()
    @State private var orderSession = OrderSession()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        // Home is always underneath; onboarding covers it until completed, so finishing onboarding
        // only animates onboarding away and never exposes the navigation background.
        ZStack {
            NavigationStack(path: $router.path) {
                HomeView()
                    .navigationDestination(for: Route.self, destination: destination)
            }
            // Black behind the screens, so their rounded corners during push/pop aren't white.
            .background(Colors.black.ignoresSafeArea())
            .environment(router)
            .accessibilityHidden(!hasCompletedOnboarding)
            .zIndex(0)

            if !hasCompletedOnboarding {
                OnboardingView()
                    .zIndex(1)
                    .transition(.blurReplace)
            }
        }
        .environment(downloads)
        .environment(rates)
        .environment(orderSession)
        .task {
            await rates.load()
        }
        .task {
            // Connects to the translation service at launch, while Home is idle. Connecting first while
            // Scan starts the camera sometimes left the connection broken (every language "not
            // installed") until relaunch; see `LanguageDownloads.isDisconnected(_:)`.
            await downloads.refresh()
        }
        .onAppear {
            // Drafts aren't saved anymore; this clears any an earlier version left on disk.
            modelContext.discardDraft()
        }
        .animation(.default, value: hasCompletedOnboarding)
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .scan:
            ScanView()
        case .translation(let photo):
            TranslationView(photo: photo)
        case .order(let order):
            OrderView(order: order)
        case .dishDetails(let dish):
            DishDetailsView(dish: dish)
        }
    }
}

enum StorageKeys {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    /// Language code of the last chosen menu language, e.g. "es".
    static let menuLanguage = "menuLanguage"
    /// ISO code of the last chosen menu currency, e.g. "MXN".
    static let menuCurrency = "menuCurrency"
    /// Codes of menu languages seen installed for translation, e.g. ["es", "fr"].
    static let installedLanguages = "installedLanguages"
}

#Preview {
    RootView()
}
