import SwiftUI

/// Bottom panel for choosing the language of the scanned menu, styled like a sheet.
///
/// It's drawn inside the Translation screen rather than presented as a real sheet: Apple's download
/// prompt is itself a sheet, and handing over between two sheets made ours reopen full screen and
/// lose later download prompts. As a panel it simply stays underneath while Apple's prompt is up.
struct LanguagePicker: View {
    @Binding var selection: MenuLanguage
    let downloads: LanguageDownloads
    let onClose: () -> Void

    /// How far the panel is dragged down. Kept (not reset) when a swipe closes it, so it slides
    /// away from where the finger let go instead of jumping back first.
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                Text("Choose language")
                    .setFontStyle(Fonts.textXlBold)
                    .foregroundStyle(Colors.text)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(MenuLanguage.menuLanguages) { language in
                        let state = downloads.state(of: language)
                        Button {
                            // Only downloaded languages can be chosen; tapping a missing one offers the download.
                            switch state {
                            case .downloaded:
                                // Played directly: the panel closes at once, which could cut off
                                // a `.sensoryFeedback` waiting for the next update.
                                UISelectionFeedbackGenerator().selectionChanged()
                                selection = language
                                onClose()
                            case .notDownloaded:
                                downloads.download(language)
                            case .unsupported:
                                break
                            }
                        } label: {
                            LanguageRow(language: language) {
                                accessory(for: state, isSelected: language == selection)
                            }
                            .overlay {
                                // The chosen language can't be used until it's downloaded.
                                if language == selection, state != .downloaded {
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Colors.danger, lineWidth: 1)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    if downloads.hasMissingLanguages {
                        Text("\(Image(systemName: "wifi")) Wi-Fi recommended for downloads.")
                            .setFontStyleMultiline(Fonts.textXs)
                            .foregroundStyle(Colors.text)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 40)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity)
        .frame(height: 620)
        .background(Colors.white, in: UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32))
        .offset(y: dragOffset)
        // High priority: once the finger moves it's a swipe, which cancels the card's tap — otherwise
        // releasing on a card (it moves with the finger) also selects it or starts a download.
        // A plain tap never reaches the drag distance, so cards still respond to taps.
        .highPriorityGesture(swipeDown)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onClose)
    }

    /// Swipe down to close, like a system sheet.
    private var swipeDown: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                dragOffset = max(value.translation.height, 0)
            }
            .onEnded { value in
                if value.translation.height > 120 || value.predictedEndTranslation.height > 300 {
                    onClose()
                } else {
                    withAnimation(.smooth(duration: 0.25)) {
                        dragOffset = 0
                    }
                }
            }
    }

    @ViewBuilder
    private func accessory(for state: LanguageDownloads.State, isSelected: Bool) -> some View {
        switch state {
        case .downloaded:
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        case .notDownloaded:
            Image(systemName: "arrow.down.circle")
                .accessibilityLabel("Download")
        case .unsupported:
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(Colors.text.opacity(0.4))
                .accessibilityLabel("Not available on this device")
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Colors.black.ignoresSafeArea()
        LanguagePicker(selection: .constant(.spanish), downloads: LanguageDownloads(), onClose: {})
    }
    .ignoresSafeArea()
}
