//
//  MainTabView.swift
//  OmniStore
//

import Foundation
import SwiftUI
import OmnistoreKit

struct MainTabView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var installManager: InstallManager

    @State private var selectedTab = 0

    private var twoFactorBinding: Binding<Bool> {
        Binding(
            get: {
                auth.phase == .awaitingTwoFactor || auth.phase == .verifyingTwoFactor
            },
            set: { isPresented in
                if !isPresented,
                   auth.phase == .awaitingTwoFactor || auth.phase == .verifyingTwoFactor {
                    auth.cancelTwoFactor()
                }
            }
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                LibraryView()
                    .tag(0)
                    .tabItem {
                        Label("Library", systemImage: "square.stack.3d.up.fill")
                    }

                BrowseView()
                    .tag(1)
                    .tabItem {
                        Label("Browse", systemImage: "sparkles")
                    }

                SettingsView()
                    .tag(2)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
            }
            .accentColor(OmniTheme.accent)

            if installManager.isActivityVisible {
                InstallActivityCard(
                    progress: installManager.progress,
                    appName: installManager.activeAppName,
                    isMock: installManager.installerIsMock,
                    onCancel: {
                        installManager.cancelInstallation()
                    },
                    onDismiss: {
                        installManager.dismissInstallActivity()
                    }
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 58)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: installManager.isActivityVisible)
        .sheet(isPresented: twoFactorBinding) {
            TwoFactorSheet()
                .environmentObject(auth)
                .interactiveDismissDisabled(auth.phase == .verifyingTwoFactor)
        }
        .onAppear {
            auth.savePreferences()
        }
    }
}
