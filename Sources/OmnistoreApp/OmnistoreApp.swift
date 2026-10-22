//
//  OmnistoreApp.swift
//  OmniStore
//

import Foundation
import SwiftUI
import OmnistoreKit

@main
struct OmniStoreApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var authManager: AuthManager
    @StateObject private var installManager: InstallManager

    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)

        let auth = AuthManager(settings: settings)
        _authManager = StateObject(wrappedValue: auth)
        _installManager = StateObject(wrappedValue: InstallManager(authManager: auth))
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(settings)
                .environmentObject(authManager)
                .environmentObject(installManager)
                .preferredColorScheme(.dark)
                .tint(OmniTheme.accent)
        }
    }
}
