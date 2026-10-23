import SwiftUI
import Translation

extension View {
    /// Presents the system download sheet for `downloads.request` and updates `downloads` when it closes.
    func languageDownloadTask(_ downloads: LanguageDownloads) -> some View {
        background {
            if let request = downloads.request {
                // New identity per request, so every tap gets a fresh translation session.
                Color.clear
                    .translationTask(request.configuration) { session in
                        await downloads.prepare(session, for: request)
                    }
                    .id(request.id)
            }
        }
    }
}
