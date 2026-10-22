//
//  InstallManager.swift
//  OmnistoreKit
//
//  ObservableObject that drives the full install pipeline:
//  unzip IPA -> provision -> GhostCode sign -> repackage -> minimuxer or mock.
//

#if canImport(Combine)
import Combine
import Foundation

@MainActor
public final class InstallManager: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var installedApps: [InstalledApp] = []
    @Published public private(set) var progress: PipelineProgress = .idle
    @Published public private(set) var activeAppName: String?
    @Published public private(set) var isInstalling = false
    @Published public private(set) var hasLoadedLibrary = false
    @Published public private(set) var libraryErrorMessage: String?
    @Published public private(set) var uninstallingBundleIdentifier: String?
    @Published public private(set) var deviceInstallAvailable = false

    @Published public var simulatedInstallDelay: TimeInterval {
        didSet {
            applyMockConfiguration()
        }
    }

    @Published public var simulateInstallFailure: Bool {
        didSet {
            applyMockConfiguration()
        }
    }

    // MARK: - Dependencies

    private let authManager: AuthManager
    private let libraryStore: LibraryStore
    private let installationManager: InstallationManager
    private let mockInstaller: MockInstaller
    private let defaults: UserDefaults

    private var installTask: Task<Void, Never>?

    // MARK: - Lifecycle

    public init(
        authManager: AuthManager,
        libraryStore: LibraryStore = LibraryStore(),
        installationManager: InstallationManager = InstallationManager(),
        mockInstaller: MockInstaller = MockInstaller(),
        defaults: UserDefaults = .standard
    ) {
        self.authManager = authManager
        self.libraryStore = libraryStore
        self.installationManager = installationManager
        self.mockInstaller = mockInstaller
        self.defaults = defaults

        let savedDelay = defaults.object(forKey: OmnistoreConstants.Preferences.mockInstallDelay) as? Double
        let savedFailure = defaults.object(forKey: OmnistoreConstants.Preferences.mockInstallFailure) as? Bool
        self.simulatedInstallDelay = min(max(savedDelay ?? 1.2, 0.2), 5)
        self.simulateInstallFailure = savedFailure ?? false

        applyMockConfiguration()

        Task { [weak self] in
            guard let self else { return }
            await self.refreshDeviceInstallAvailability()
            await self.reloadLibrary()
        }
    }

    // MARK: - Derived State

    public var installerIsMock: Bool {
        !deviceInstallAvailable
    }

    public var isActivityVisible: Bool {
        progress.stage != .idle
    }

    public var displayApps: [InstalledApp] {
        installedApps.isEmpty ? InstalledApp.sampleApps : installedApps
    }

    public var isShowingDemoLibrary: Bool {
        installedApps.isEmpty
    }

    // MARK: - Library

    public func reloadLibrary() async {
        do {
            let apps = try await libraryStore.load()
            installedApps = apps
            hasLoadedLibrary = true
            libraryErrorMessage = nil
        } catch {
            hasLoadedLibrary = true
            libraryErrorMessage = message(for: error)
        }
    }

    public func uninstall(_ app: InstalledApp) {
        guard !isInstalling, uninstallingBundleIdentifier == nil else { return }
        uninstallingBundleIdentifier = app.bundleIdentifier

        Task { [weak self] in
            guard let self else { return }
            defer { self.uninstallingBundleIdentifier = nil }

            do {
                try await self.mockInstaller.uninstallApp(bundleIdentifier: app.bundleIdentifier)
                let apps = try await self.libraryStore.remove(bundleIdentifier: app.bundleIdentifier)
                self.installedApps = apps

                do {
                    try await self.libraryStore.removeIcon(at: app.iconURL)
                } catch {
                    self.libraryErrorMessage = self.message(for: error)
                }
            } catch {
                self.libraryErrorMessage = self.message(for: error)
            }
        }
    }

    public func dismissLibraryError() {
        libraryErrorMessage = nil
    }

    public func refreshDeviceInstallAvailability() async {
        deviceInstallAvailable = await installationManager.canInstallOnDevice()
    }

    // MARK: - Installation

    public func install(ipaURL: URL) {
        guard !isInstalling else { return }

        let securityScopedAccess = ipaURL.startAccessingSecurityScopedResource()
        activeAppName = nil
        progress = .preparing(0.02, "Opening the IPA…")
        isInstalling = true

        installTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if securityScopedAccess {
                    ipaURL.stopAccessingSecurityScopedResource()
                }
                self.isInstalling = false
                self.installTask = nil
            }

            await self.runInstall(ipaURL: ipaURL)
        }
    }

    public func cancelInstallation() {
        installTask?.cancel()
    }

    public func dismissInstallActivity() {
        guard !isInstalling else { return }
        progress = .idle
        activeAppName = nil
    }

    private func runInstall(ipaURL: URL) async {
        var preparedInstallation: InstallationManager.PreparedInstallation?
        var savedIconURL: URL?

        do {
            let authManager = self.authManager
            let installationManager = self.installationManager
            let assetsProvider: InstallationManager.AssetsProvider = { metadata in
                guard authManager.isSignedIn else { return nil }
                return try await authManager.signingAssets(
                    bundleIdentifier: metadata.bundleIdentifier,
                    appName: metadata.name,
                    deviceUDID: authManager.deviceUDID
                )
            }
            let progressHandler: InstallationManager.ProgressHandler = { [weak self] update in
                self?.progress = update
            }

            let prepared = try await installationManager.prepare(
                ipaURL: ipaURL,
                assetsProvider: assetsProvider,
                progress: progressHandler
            )
            preparedInstallation = prepared
            activeAppName = prepared.metadata.name

            try Task.checkCancellation()
            await refreshDeviceInstallAvailability()

            if deviceInstallAvailable {
                try await installationManager.installOnDevice(
                    prepared,
                    progress: progressHandler
                )
            } else {
                progress = .installing(
                    0.75,
                    "No device gateway configured. Running the mock installer…"
                )
                try await mockInstaller.installApp(ipaURL: prepared.signedIPAURL) { [weak self] fraction in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        let mapped = 0.75 + (min(max(fraction, 0), 1) * 0.22)
                        self.progress = .installing(
                            mapped,
                            "Mock installer progress \(Int(fraction * 100))%"
                        )
                    }
                }
            }

            try Task.checkCancellation()

            if let iconData = prepared.metadata.iconData {
                do {
                    savedIconURL = try await libraryStore.saveIcon(
                        iconData,
                        bundleIdentifier: prepared.metadata.bundleIdentifier
                    )
                } catch {
                    libraryErrorMessage = message(for: error)
                }
            }

            let now = Date()
            let fallbackExpiration = now.addingTimeInterval(OmnistoreConstants.freeCertificateValidity)
            let profileExpiration = prepared.provisioningProfileExpiration
            let expiration = (profileExpiration ?? fallbackExpiration) > now
                ? (profileExpiration ?? fallbackExpiration)
                : fallbackExpiration

            let installedApp = InstalledApp(
                bundleIdentifier: prepared.metadata.bundleIdentifier,
                name: prepared.metadata.name,
                version: prepared.metadata.version,
                developerName: prepared.isAdHocSigned ? "OmniStore Demo" : "Apple Development",
                installedDate: now,
                expirationDate: expiration,
                iconURL: savedIconURL,
                iconSystemName: savedIconURL == nil ? "shippingbox.fill" : nil,
                certificateId: prepared.certificateID,
                originalIPAFileName: ipaURL.lastPathComponent
            )

            let apps = try await libraryStore.upsert(installedApp)
            installedApps = apps
            hasLoadedLibrary = true

            let mode = prepared.isAdHocSigned
                ? " (demo install)"
                : (deviceInstallAvailable ? "" : " (simulated)")
            progress = .completed("\(installedApp.name) installed successfully\(mode).")
            await installationManager.discard(prepared)
        } catch {
            if Task.isCancelled || error is CancellationError {
                progress = .failed("Installation was cancelled.")
            } else {
                progress = .failed(message(for: error))
            }

            if let savedIconURL {
                do {
                    try await libraryStore.removeIcon(at: savedIconURL)
                } catch {
                    // The install failure is the actionable error; icon cleanup is best-effort.
                }
            }
            if let preparedInstallation {
                await installationManager.discard(preparedInstallation)
            }
        }
    }

    // MARK: - Mock Configuration

    private func applyMockConfiguration() {
        mockInstaller.configure(
            simulatedDelay: simulatedInstallDelay,
            shouldFail: simulateInstallFailure
        )
        defaults.set(simulatedInstallDelay, forKey: OmnistoreConstants.Preferences.mockInstallDelay)
        defaults.set(simulateInstallFailure, forKey: OmnistoreConstants.Preferences.mockInstallFailure)
    }

    private func message(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return error.localizedDescription
    }
}
#endif
