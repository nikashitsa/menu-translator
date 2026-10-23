import SwiftUI

struct OnboardingView: View {
    @AppStorage(StorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(LanguageDownloads.self) private var downloads

    private let languages: [MenuLanguage] = MenuLanguage.menuLanguages

    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Setup")
                    .setFontStyle(Fonts.textXlBold)
                Text("Download the menu languages you need.")
                    .setFontStyleMultiline(Fonts.textMd)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(languages) { language in
                    Button {
                        downloads.download(language)
                    } label: {
                        LanguageRow(language: language) {
                            accessory(for: downloads.state(of: language))
                        }
                    }
                    // Taps on installed or unavailable languages are ignored by `download`.
                    .buttonStyle(.plain)
                }
                if downloads.hasMissingLanguages {
                    Text("\(Image(systemName: "wifi")) Wi-Fi recommended for downloads.")
                        .setFontStyleMultiline(Fonts.textXs)
                }
            }
        }
        .foregroundStyle(Colors.text)
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom) {
            Button {
                hasCompletedOnboarding = true
            } label: {
                Text("Continue").setFontStyle(Fonts.textMdBold)
            }
            .buttonStyle(PrimaryButton())
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Colors.white)
        }
        .background(Colors.white)
        .languageDownloadTask(downloads)
        .task {
            await downloads.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            // Languages may have been added or removed in Settings meanwhile.
            if phase == .active {
                Task { await downloads.refresh() }
            }
        }
    }

    @ViewBuilder
    private func accessory(for state: LanguageDownloads.State) -> some View {
        switch state {
        case .notDownloaded:
            Image(systemName: "arrow.down.circle")
                .accessibilityLabel("Download")
        case .downloaded:
            Image(systemName: "checkmark.circle")
                .accessibilityLabel("Downloaded")
        case .unsupported:
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(Colors.text.opacity(0.4))
                .accessibilityLabel("Not available on this device")
        }
    }
}

#Preview {
    OnboardingView()
        .environment(LanguageDownloads())
}
