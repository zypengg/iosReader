//
//  iosReaderApp.swift
//  iosReader
//
//  Created by Zhao Yi Peng on 2025-06-24.
//

import SwiftUI

@main
struct iosReaderApp: App {
    @StateObject private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(themeManager.getColorScheme())
                .environmentObject(themeManager)
        }
    }
}
