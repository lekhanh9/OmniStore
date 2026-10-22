//
//  LibraryView.swift
//  OmniStore
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import OmnistoreKit

struct LibraryView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var installManager: InstallManager

    @State private var isImporterPresented = false
    @State private var activeAlert: LibraryAlert?

    private var apps: [InstalledApp] {
        installManager.displayApps
    }

    private var activeCount: Int {
        apps.filter { $0.status == .active }.count
    }

    private var renewalCount: Int {
        apps.filter { $0.status != .active }.count
    }

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    if installManager.isShowingDemoLibrary {
                        previewBanner
                    }

                    if let error = installManager.libraryErrorMessage {
                        OmniErrorBanner(message: error) {
                            installManager.dismissLibraryError()
                        }
                    }

                    statsRow

                    librarySection

                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 116)
            }
            .refreshable {
                await installManager.reloadLibrary()
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.ipa]
        ) { result in
            handleImport(result)
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .uninstall(let app):
                return Alert(
                    title: Text("Uninstall \(app.name)?"),
                    message: Text(
                        installManager.installerIsMock
                            ? "This removes the app from your OmniStore library. The mock installer does not modify apps installed on your Home Screen."
                            : "This uninstalls the app from this device and removes it from your OmniStore library."
                    ),
                    primaryButton: .destructive(Text("Uninstall")) {
                        installManager.uninstall(app)
                    },
                    secondaryButton: .cancel()
                )
            case .importFailure(let message):
                return Alert(
                    title: Text("Couldn’t Import IPA"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Library")
                    .font(OmniTypography.display(34))
                    .foregroundColor(OmniTheme.primaryText)
                Text(greeting)
                    .font(OmniTypography.body(13))
                    .foregroundColor(OmniTheme.secondaryText)
            }

            Spacer(minLength: 8)

            if auth.isSignedIn {
                ZStack {
                    Circle()
                        .fill(OmniTheme.accent.opacity(0.14))
                    Circle()
                        .strokeBorder(OmniTheme.accent.opacity(0.25), lineWidth: 1)
                    Image(systemName: "person.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(OmniTheme.accent)
                }
                .frame(width: 40, height: 40)
                .accessibilityLabel("Signed in as \(auth.appleID)")
            }

            Button {
                isImporterPresented = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(OmniTheme.primaryText)
            }
            .buttonStyle(OmniIconButtonStyle(size: 46))
            .accessibilityLabel("Import an IPA")
        }
    }

    private var greeting: String {
        if auth.isSignedIn {
            return "Signed in as \(auth.appleID)."
        }
        return "Apps, signed and ready."
    }

    // MARK: - Demo Banner

    private var previewBanner: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(OmniTheme.heroGradient)

            Circle()
                .fill(OmniTheme.accent.opacity(0.24))
                .frame(width: 150, height: 150)
                .blur(radius: 42)
                .offset(x: 40, y: -54)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 11) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                        Image(systemName: "sparkles")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white.opacity(0.94))
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("A preview of your library")
                            .font(OmniTypography.title(16))
                            .foregroundColor(.white.opacity(0.95))
                        Text("Sample apps, zero promises.")
                            .font(OmniTypography.body(12))
                            .foregroundColor(.white.opacity(0.56))
                    }
                }

                Text("These four cards show how installed apps will look. Import an IPA to sign it and replace this preview with the real thing.")
                    .font(OmniTypography.body(12))
                    .foregroundColor(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    isImporterPresented = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.down.app.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Import your first IPA")
                    }
                    .font(OmniTypography.label(12))
                    .foregroundColor(.white.opacity(0.95))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.white.opacity(0.13)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(19)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.28), radius: 20, x: 0, y: 10)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(
                symbol: "square.stack.3d.up.fill",
                value: "\(apps.count)",
                label: installManager.isShowingDemoLibrary ? "Preview" : "Apps",
                tint: OmniTheme.accent
            )
            StatTile(
                symbol: "checkmark.seal.fill",
                value: "\(activeCount)",
                label: "Active",
                tint: OmniTheme.sky
            )
            StatTile(
                symbol: "clock.fill",
                value: "\(renewalCount)",
                label: "Renewals",
                tint: OmniTheme.warm
            )
        }
    }

    // MARK: - App List

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OmniSectionHeader(
                title: installManager.isShowingDemoLibrary ? "Preview apps" : "Your apps",
                subtitle: installManager.isShowingDemoLibrary
                    ? "Real installs will appear here."
                    : "Signed on this device.",
                trailingText: "\(apps.count) total"
            )

            ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                LibraryAppCard(
                    app: app,
                    paletteIndex: index,
                    isPreview: installManager.isShowingDemoLibrary,
                    onUninstall: {
                        activeAlert = .uninstall(app)
                    }
                )
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text("Signed locally. Credentials stay out of the Keychain.")
                    .font(OmniTypography.body(10))
            }
            .foregroundColor(OmniTheme.tertiaryText)

            if installManager.hasLoadedLibrary && installManager.installedApps.isEmpty {
                Text("Sample apps are visual placeholders and cannot be uninstalled.")
                    .font(OmniTypography.body(10))
                    .foregroundColor(OmniTheme.tertiaryText.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    // MARK: - Actions

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                try IPAFileValidator.validate(url)
            } catch {
                activeAlert = .importFailure(importErrorMessage(error))
                return
            }

            installManager.install(ipaURL: url)
        case .failure(let error):
            activeAlert = .importFailure(error.localizedDescription)
        }
    }

    private func importErrorMessage(_ error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return error.localizedDescription
    }
}

// MARK: - Supporting Views

private struct StatTile: View {
    let symbol: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        GlassCard(cornerRadius: 18, padding: 13) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(tint)
                Text(value)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundColor(OmniTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(OmniTypography.body(10))
                    .foregroundColor(OmniTheme.tertiaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct LibraryAppCard: View {
    let app: InstalledApp
    let paletteIndex: Int
    let isPreview: Bool
    let onUninstall: () -> Void

    var body: some View {
        GlassCard(cornerRadius: 22, padding: 14) {
            VStack(spacing: 12) {
                HStack(spacing: 13) {
                    AppIconView(app: app, size: 56, paletteIndex: paletteIndex)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(app.name)
                                .font(OmniTypography.title(16))
                                .foregroundColor(OmniTheme.primaryText)
                                .lineLimit(1)
                            if app.isDemo && !isPreview {
                                OmniPill(text: "Demo", color: OmniTheme.sky)
                            }
                        }

                        Text(subtitle)
                            .font(OmniTypography.body(11))
                            .foregroundColor(OmniTheme.secondaryText)
                            .lineLimit(1)

                        HStack(spacing: 5) {
                            Image(systemName: "clock")
                                .font(.system(size: 9, weight: .semibold))
                            Text(expiryLabel)
                                .font(OmniTypography.label(10))
                        }
                        .foregroundColor(OmniTheme.statusColor(for: app.status).opacity(0.90))
                    }

                    Spacer(minLength: 4)

                    if !isPreview {
                        Menu {
                            Button(role: .destructive, action: onUninstall) {
                                Label("Uninstall", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(OmniTheme.secondaryText)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Color.white.opacity(0.06)))
                        }
                    }
                }

                HStack(spacing: 6) {
                    StatusPill(app: app)
                    Spacer()
                    if isPreview {
                        Text("PREVIEW")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .tracking(1.0)
                            .foregroundColor(OmniTheme.tertiaryText)
                    } else {
                        Text("Added \(OmniFormat.abbreviatedDate(app.installedDate))")
                            .font(OmniTypography.body(10))
                            .foregroundColor(OmniTheme.tertiaryText)
                    }
                }
            }
        }
    }

    private var subtitle: String {
        let developer = app.developerName ?? "Unknown developer"
        return "\(developer) · v\(app.version)"
    }

    private var expiryLabel: String {
        switch app.status {
        case .active:
            return "\(app.daysRemaining) \(app.daysRemaining == 1 ? "day" : "days") left"
        case .expiringSoon:
            return "Renews in \(app.daysRemaining) \(app.daysRemaining == 1 ? "day" : "days")"
        case .expired:
            return "Expired"
        }
    }
}

private enum LibraryAlert: Identifiable {
    case uninstall(InstalledApp)
    case importFailure(String)

    var id: String {
        switch self {
        case .uninstall(let app):
            return "uninstall-\(app.bundleIdentifier)"
        case .importFailure(let message):
            return "import-\(message)"
        }
    }
}
