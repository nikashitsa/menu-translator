//
//  MainApp.swift
//  Menu Translator
//
//  Created by Nikita Verkhovin on 08.10.2026.
//

import SwiftData
import SwiftUI

@main
struct MainApp: App {
    var body: some Scene {
        WindowGroup {
            if let container = ScreenshotMode.container {
                RootView()
                    .modelContainer(container)
            } else {
                RootView()
                    // No autosave: orders are written only when "Save" is tapped on the Order screen.
                    .modelContainer(for: Order.self, isAutosaveEnabled: false)
            }
        }
    }
}
