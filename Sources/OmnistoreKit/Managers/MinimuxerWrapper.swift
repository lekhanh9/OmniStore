//
//  MinimuxerWrapper.swift
//  OmnistoreKit
//

import Foundation

#if canImport(Minimuxer) && os(iOS)
import Minimuxer
#endif

public enum MinimuxerWrapperError: Error, LocalizedError, Sendable, Equatable {
    case unsupportedPlatform
    case pairingFileMissing(String)
    case pairingFileUnreadable(String)
    case notStarted
    case operationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedPlatform:
            return "Minimuxer is only available on iOS."
        case .pairingFileMissing(let path):
            return "No pairing file was found at \(path)."
        case .pairingFileUnreadable(let reason):
            return "The pairing file could not be read: \(reason)"
        case .notStarted:
            return "The minimuxer device gateway has not been started."
        case .operationFailed(let reason):
            return reason
        }
    }
}

public enum PairingMode: String, Sendable, CaseIterable {
    case automatic
    case lockdown
    case rppairing
}

public actor MinimuxerWrapper {
    public struct Configuration: Sendable, Equatable {
        public let pairingFileURL: URL
        public let mountPath: URL

        public init(pairingFileURL: URL, mountPath: URL) {
            self.pairingFileURL = pairingFileURL
            self.mountPath = mountPath
        }
    }

    public static let shared = MinimuxerWrapper()

    private var configuration: Configuration?
    private var isStarted = false

    public init(configuration: Configuration? = nil) {
        self.configuration = configuration
    }

    public nonisolated var isSupported: Bool {
        #if canImport(Minimuxer) && os(iOS)
        return true
        #else
        return false
        #endif
    }

    public nonisolated static var defaultPairingFileURL: URL {
        documentsDirectory
            .appendingPathComponent(OmnistoreConstants.rootDirectoryName, isDirectory: true)
            .appendingPathComponent(OmnistoreConstants.pairingDirectoryName, isDirectory: true)
            .appendingPathComponent(OmnistoreConstants.pairingFileName)
    }

    public nonisolated static var defaultMountPath: URL {
        documentsDirectory
            .appendingPathComponent(OmnistoreConstants.rootDirectoryName, isDirectory: true)
    }

    public func configure(pairingFileURL: URL, mountPath: URL? = nil) {
        configuration = Configuration(
            pairingFileURL: pairingFileURL,
            mountPath: mountPath ?? Self.defaultMountPath
        )
    }

    public func availabilityReason() -> String? {
        guard isSupported else {
            return MinimuxerWrapperError.unsupportedPlatform.localizedDescription
        }
        // Make Documents/Omnistore/Pairing visible in the Files app before checking.
        try? FileManager.default.createDirectory(
            at: Self.defaultPairingFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if let configuration,
           FileManager.default.fileExists(atPath: configuration.pairingFileURL.path) {
            return nil
        }
        if FileManager.default.fileExists(atPath: Self.defaultPairingFileURL.path) {
            return nil
        }
        return MinimuxerWrapperError.pairingFileMissing(Self.defaultPairingFileURL.path).localizedDescription
    }

    public func start(preferred: PairingMode = .automatic) async throws {
        #if canImport(Minimuxer) && os(iOS)
        guard !isStarted else { return }

        let configuration = try resolvedConfiguration()
        do {
            try FileManager.default.createDirectory(
                at: configuration.mountPath,
                withIntermediateDirectories: true
            )
        } catch {
            throw MinimuxerWrapperError.pairingFileUnreadable(
                "Could not create the mount directory: \(error.localizedDescription)"
            )
        }

        let pairingData: Data
        do {
            pairingData = try Data(contentsOf: configuration.pairingFileURL)
        } catch {
            throw MinimuxerWrapperError.pairingFileUnreadable(error.localizedDescription)
        }
        guard let pairingContents = String(data: pairingData, encoding: .utf8),
              !pairingContents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MinimuxerWrapperError.pairingFileUnreadable(
                "The pairing file is empty or is not an XML property list."
            )
        }

        let core = Minimuxer.shared.core
        await bindLocalVPN(core: core)

        let mountPath = configuration.mountPath.path
        do {
            switch preferred {
            case .automatic:
                try await core.start(
                    pairingFile: pairingContents,
                    mountPath: mountPath,
                    preferred: nil
                )
            case .lockdown:
                try await core.start(
                    pairingFile: pairingContents,
                    mountPath: mountPath,
                    preferred: .lockdown
                )
            case .rppairing:
                try await core.start(
                    pairingFile: pairingContents,
                    mountPath: mountPath,
                    preferred: .rppairing
                )
            }
        } catch {
            throw MinimuxerWrapperError.operationFailed(operationMessage(error, core: core))
        }
        isStarted = true
        #else
        throw MinimuxerWrapperError.unsupportedPlatform
        #endif
    }

    public func stop() async throws {
        #if canImport(Minimuxer) && os(iOS)
        guard isStarted else { return }
        let core = Minimuxer.shared.core
        do {
            try await core.stop()
        } catch {
            throw MinimuxerWrapperError.operationFailed(operationMessage(error, core: core))
        }
        isStarted = false
        #else
        throw MinimuxerWrapperError.unsupportedPlatform
        #endif
    }

    public func isReady(
        withNetworkCheck: Bool = true,
        withDDIMountCheck: Bool = false
    ) async -> Bool {
        #if canImport(Minimuxer) && os(iOS)
        guard isStarted else { return false }
        let result = await Minimuxer.shared.core.isReady(
            withNetworkCheck: withNetworkCheck,
            withDDIMountCheck: withDDIMountCheck
        )
        switch result {
        case .success(let ready):
            return ready
        case .failure:
            return false
        }
        #else
        return false
        #endif
    }

    public func fetchUDID() async throws -> String {
        #if canImport(Minimuxer) && os(iOS)
        guard isStarted else { throw MinimuxerWrapperError.notStarted }
        let core = Minimuxer.shared.core
        do {
            return try await core.fetchUDID()
        } catch {
            throw MinimuxerWrapperError.operationFailed(operationMessage(error, core: core))
        }
        #else
        throw MinimuxerWrapperError.unsupportedPlatform
        #endif
    }

    public func installIPA(at ipaURL: URL, bundleIdentifier: String) async throws {
        #if canImport(Minimuxer) && os(iOS)
        try await start()
        guard isStarted else { throw MinimuxerWrapperError.notStarted }

        let ipaBytes: Data
        do {
            ipaBytes = try Data(contentsOf: ipaURL)
        } catch {
            throw MinimuxerWrapperError.operationFailed(
                "The signed IPA could not be read: \(error.localizedDescription)"
            )
        }
        guard !ipaBytes.isEmpty else {
            throw MinimuxerWrapperError.operationFailed("The signed IPA is empty.")
        }

        let core = Minimuxer.shared.core
        do {
            try await core.sendIpaAfc(bundleId: bundleIdentifier, ipaBytes: ipaBytes)
            try await core.installIpa(bundleId: bundleIdentifier)
        } catch {
            throw MinimuxerWrapperError.operationFailed(operationMessage(error, core: core))
        }
        #else
        throw MinimuxerWrapperError.unsupportedPlatform
        #endif
    }

    public func removeApp(bundleIdentifier: String) async throws {
        #if canImport(Minimuxer) && os(iOS)
        try await start()
        guard isStarted else { throw MinimuxerWrapperError.notStarted }
        let core = Minimuxer.shared.core
        do {
            try await core.removeApp(bundleId: bundleIdentifier)
        } catch {
            throw MinimuxerWrapperError.operationFailed(operationMessage(error, core: core))
        }
        #else
        throw MinimuxerWrapperError.unsupportedPlatform
        #endif
    }

    private func resolvedConfiguration() throws -> Configuration {
        if let configuration {
            guard FileManager.default.fileExists(atPath: configuration.pairingFileURL.path) else {
                throw MinimuxerWrapperError.pairingFileMissing(configuration.pairingFileURL.path)
            }
            return configuration
        }

        let defaultURL = Self.defaultPairingFileURL
        guard FileManager.default.fileExists(atPath: defaultURL.path) else {
            throw MinimuxerWrapperError.pairingFileMissing(defaultURL.path)
        }
        let configuration = Configuration(
            pairingFileURL: defaultURL,
            mountPath: Self.defaultMountPath
        )
        self.configuration = configuration
        return configuration
    }

    #if canImport(Minimuxer) && os(iOS)
    private func operationMessage(_ error: Error, core: any MinimuxerAPI) -> String {
        if let typed = error as? MinimuxerError {
            return core.describeError(typed)
        }
        return error.localizedDescription
    }

    private func bindLocalVPN(core: any MinimuxerAPI) async {
        let peerIP = OmnistoreConstants.defaultVPNPeerIP
        let binding = ConnectionConfigBinding(
            setTunnelIfaceIp: { _ in },
            setTunnelPeerIp: { _ in },
            setTunnelPeerSubnetMask: { _ in },
            setTunnelPeerReachable: { _ in },
            setTunnelIfaceSubnetMask: { _ in },
            getRemoteServerIp: { "" },
            setRemoteReachable: { _ in },
            getOverrideTunnelPeerIp: { peerIP },
            setOverrideTunnelPeerReachable: { _ in },
            getConnectionMode: { DeviceConnectionMode.localVPN }
        )
        await core.bindConnectionConfig(binding)
    }
    #endif

    private nonisolated static var documentsDirectory: URL {
        let fileManager = FileManager.default
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documentsURL
        }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent("Documents", isDirectory: true)
    }
}

