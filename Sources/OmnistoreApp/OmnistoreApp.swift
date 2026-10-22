//
//  OmnistoreApp.swift
//  OmniStore
//

import Foundation
import SwiftUI
import OmnistoreKit

@main
struct OmniStoreApp: App {
    @StateObject private var authManager: AuthManager
    @StateObject private var installManager: InstallManager

    init() {
        let auth = AuthManager()
        _authManager = StateObject(wrappedValue: auth)
        _installManager = StateObject(wrappedValue: InstallManager(authManager: auth))
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(authManager)
                .environmentObject(installManager)
                .preferredColorScheme(.dark)
                .tint(OmniTheme.accent)
        }
    }
}
