//
//  IdentityStore.swift
//  OmnistoreKit
//
//  Zero-Keychain credential storage. The .p12, X.509 certificate and
//  .mobileprovision payloads live inside the app sandbox under Documents.
//

import Foundation

public actor IdentityStore {
    public let baseDirectory: URL
    public let profilesDirectory: URL

    private let identityFileURL: URL
    private let certificateFileURL: URL
    private let metadataFileURL: URL

    public init(baseDirectory: URL? = nil) {
        let root = baseDirectory ?? Self.defaultBaseDirectory()
        self.baseDirectory = root
        self.profilesDirectory = root.appendingPathComponent(OmnistoreConstants.profilesDirectoryName, isDirectory: true)
        self.identityFileURL = root.appendingPathComponent(OmnistoreConstants.identityFileName)
        self.certificateFileURL = root.appendingPathComponent(OmnistoreConstants.certificateFileName)
        self.metadataFileURL = root.appendingPathComponent(OmnistoreConstants.identityMetadataFileName)
    }

    public nonisolated static func defaultBaseDirectory() -> URL {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Documents", isDirectory: true)
        return documentsURL.appendingPathComponent(OmnistoreConstants.rootDirectoryName, isDirectory: true)
    }

    // MARK: - Identity

    public func saveIdentity(
        p12Data: Data,
        certificateDER: Data,
        metadata: StoredIdentityMetadata
    ) throws {
        try ensureDirectories()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let metadataData: Data
        do {
            metadataData = try encoder.encode(metadata)
        } catch {
            throw OmnistoreError.storage("Could not encode identity metadata: \(error.localizedDescription)")
        }

        try write(certificateDER, to: certificateFileURL, label: "certificate")
        try write(p12Data, to: identityFileURL, label: "identity archive")
        try write(metadataData, to: metadataFileURL, label: "identity metadata")
    }

    public func loadIdentity() throws -> StoredIdentity? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: metadataFileURL.path) else {
            return nil
        }
        guard fileManager.fileExists(atPath: identityFileURL.path),
              fileManager.fileExists(atPath: certificateFileURL.path) else {
            throw OmnistoreError.storage("The stored signing identity is incomplete. Remove it and prepare a new one.")
        }

        let metadataData = try read(metadataFileURL, label: "identity metadata")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let metadata: StoredIdentityMetadata
        do {
            metadata = try decoder.decode(StoredIdentityMetadata.self, from: metadataData)
        } catch {
            throw OmnistoreError.storage("Could not decode identity metadata: \(error.localizedDescription)")
        }

        let p12Data = try read(identityFileURL, label: "identity archive")
        let certificateDER = try read(certificateFileURL, label: "certificate")
        return StoredIdentity(metadata: metadata, p12Data: p12Data, certificateDER: certificateDER)
    }

    public func identityPaths() -> (p12: String, certificate: String) {
        (identityFileURL.path, certificateFileURL.path)
    }

    public func removeCredentials() throws {
        let fileManager = FileManager.default
        try removeIfPresent(identityFileURL)
        try removeIfPresent(certificateFileURL)
        try removeIfPresent(metadataFileURL)

        guard fileManager.fileExists(atPath: profilesDirectory.path) else { return }

        let profileURLs: [URL]
        do {
            profileURLs = try fileManager.contentsOfDirectory(
                at: profilesDirectory,
                includingPropertiesForKeys: nil
            )
        } catch {
            throw OmnistoreError.storage("Could not enumerate provisioning profiles: \(error.localizedDescription)")
        }

        for url in profileURLs where url.pathExtension.lowercased() == OmnistoreConstants.provisioningProfileExtension {
            try removeIfPresent(url)
        }
    }

    // MARK: - Provisioning Profiles

    @discardableResult
    public func saveProvisioningProfile(_ data: Data, bundleIdentifier: String) throws -> URL {
        try ensureDirectories()
        let fileName = try profileFileName(for: bundleIdentifier)
        let url = profilesDirectory.appendingPathComponent(fileName)
        try write(data, to: url, label: "provisioning profile")
        return url
    }

    public func provisioningProfileURL(for bundleIdentifier: String) throws -> URL? {
        let fileName = try profileFileName(for: bundleIdentifier)
        let url = profilesDirectory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    public func profileCount() throws -> Int {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: profilesDirectory.path) else { return 0 }

        let urls: [URL]
        do {
            urls = try fileManager.contentsOfDirectory(
                at: profilesDirectory,
                includingPropertiesForKeys: nil
            )
        } catch {
            throw OmnistoreError.storage("Could not enumerate provisioning profiles: \(error.localizedDescription)")
        }

        return urls.filter {
            $0.pathExtension.lowercased() == OmnistoreConstants.provisioningProfileExtension
        }.count
    }

    // MARK: - Helpers

    private func ensureDirectories() throws {
        let fileManager = FileManager.default
        do {
            if !fileManager.fileExists(atPath: baseDirectory.path) {
                try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
            }
            if !fileManager.fileExists(atPath: profilesDirectory.path) {
                try fileManager.createDirectory(at: profilesDirectory, withIntermediateDirectories: true)
            }
        } catch {
            throw OmnistoreError.storage("Could not create the credentials directory: \(error.localizedDescription)")
        }
    }

    private func write(_ data: Data, to url: URL, label: String) throws {
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw OmnistoreError.storage("Could not write the \(label): \(error.localizedDescription)")
        }
    }

    private func read(_ url: URL, label: String) throws -> Data {
        do {
            return try Data(contentsOf: url)
        } catch {
            throw OmnistoreError.storage("Could not read the \(label): \(error.localizedDescription)")
        }
    }

    private func removeIfPresent(_ url: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw OmnistoreError.storage("Could not remove \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    private func profileFileName(for bundleIdentifier: String) throws -> String {
        let trimmed = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw OmnistoreError.invalidConfiguration("The app bundle identifier is empty.")
        }

        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_")
        var sanitized = ""
        for scalar in trimmed.unicodeScalars {
            if allowed.contains(scalar) {
                sanitized.unicodeScalars.append(scalar)
            } else {
                sanitized.append("_")
            }
        }

        guard !sanitized.isEmpty else {
            throw OmnistoreError.invalidConfiguration("The app bundle identifier is not a valid file name.")
        }
        return "\(sanitized).\(OmnistoreConstants.provisioningProfileExtension)"
    }
}
