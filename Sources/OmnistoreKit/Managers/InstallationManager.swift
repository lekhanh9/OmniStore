//
//  InstallationManager.swift
//  OmnistoreKit
//

import Foundation

public actor InstallationManager {
    public struct PreparedInstallation: Sendable {
        public let workspaceURL: URL
        public let appBundleURL: URL
        public let signedIPAURL: URL
        public let metadata: IPAMetadata
        public let certificateID: String?
        public let provisioningProfileExpiration: Date?
        public let isAdHocSigned: Bool

        public init(
            workspaceURL: URL,
            appBundleURL: URL,
            signedIPAURL: URL,
            metadata: IPAMetadata,
            certificateID: String?,
            provisioningProfileExpiration: Date?,
            isAdHocSigned: Bool
        ) {
            self.workspaceURL = workspaceURL
            self.appBundleURL = appBundleURL
            self.signedIPAURL = signedIPAURL
            self.metadata = metadata
            self.certificateID = certificateID
            self.provisioningProfileExpiration = provisioningProfileExpiration
            self.isAdHocSigned = isAdHocSigned
        }
    }

    public typealias AssetsProvider = @MainActor @Sendable (IPAMetadata) async throws -> SigningAssets?
    public typealias ProgressHandler = @MainActor @Sendable (PipelineProgress) -> Void

    private let ipaService: IPAService
    private let signingService: SigningService
    private let minimuxer: MinimuxerWrapper

    public init(
        ipaService: IPAService = IPAService(),
        signingService: SigningService = SigningService(),
        minimuxer: MinimuxerWrapper = .shared
    ) {
        self.ipaService = ipaService
        self.signingService = signingService
        self.minimuxer = minimuxer
    }

    public func canInstallOnDevice() async -> Bool {
        await minimuxer.availabilityReason() == nil
    }

    public func prepare(
        ipaURL: URL,
        assetsProvider: AssetsProvider,
        progress: ProgressHandler
    ) async throws -> PreparedInstallation {
        await progress(.preparing(0.06, "Validating and unpacking the archive…"))
        let prepared = try await ipaService.prepare(ipaURL: ipaURL)

        await progress(.preparing(
            0.18,
            "Found \(prepared.metadata.name) \(prepared.metadata.version)"
        ))

        var signedIPAURL: URL?
        do {
            try Task.checkCancellation()
            await progress(.provisioning(0.28, "Preparing signing assets…"))
            let assets = try await assetsProvider(prepared.metadata)

            try Task.checkCancellation()
            await progress(.signing(0.45, "Signing Mach-O binaries and sealing resources…"))
            let appBundleURL = prepared.appBundleURL
            let signer = signingService
            try await Task.detached(priority: .userInitiated) {
                try signer.sign(appBundleURL: appBundleURL, assets: assets)
            }.value

            try Task.checkCancellation()
            await progress(.packaging(0.65, "Repackaging the signed application…"))
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("OmniStore-signed-\(UUID().uuidString).ipa")
            signedIPAURL = outputURL
            try await ipaService.package(appBundleURL: appBundleURL, to: outputURL)

            return PreparedInstallation(
                workspaceURL: prepared.workspaceURL,
                appBundleURL: prepared.appBundleURL,
                signedIPAURL: outputURL,
                metadata: prepared.metadata,
                certificateID: assets?.certificateID,
                provisioningProfileExpiration: assets?.provisioningProfileExpiration,
                isAdHocSigned: assets == nil
            )
        } catch {
            if let signedIPAURL {
                try? FileManager.default.removeItem(at: signedIPAURL)
            }
            await ipaService.discard(workspace: prepared.workspaceURL)
            throw error
        }
    }

    public func installOnDevice(
        _ prepared: PreparedInstallation,
        progress: ProgressHandler
    ) async throws {
        await progress(.installing(0.75, "Starting the minimuxer device gateway…"))
        try await minimuxer.start()

        await progress(.installing(
            0.88,
            "Installing \(prepared.metadata.name) on this device…"
        ))
        try await minimuxer.installIPA(
            at: prepared.signedIPAURL,
            bundleIdentifier: prepared.metadata.bundleIdentifier
        )

        await progress(.installing(0.97, "Finishing installation…"))
    }

    public func uninstallOnDevice(bundleIdentifier: String) async throws {
        try await minimuxer.removeApp(bundleIdentifier: bundleIdentifier)
    }

    public func discard(_ prepared: PreparedInstallation) async {
        await ipaService.discard(workspace: prepared.workspaceURL)
        let signedIPAURL = prepared.signedIPAURL
        guard FileManager.default.fileExists(atPath: signedIPAURL.path) else { return }
        try? FileManager.default.removeItem(at: signedIPAURL)
    }
}
