//
//  IPAService.swift
//  OmnistoreKit
//

import Foundation
import ZIPFoundation

public actor IPAService {
    public struct PreparedIPA: Sendable {
        public let workspaceURL: URL
        public let appBundleURL: URL
        public let metadata: IPAMetadata

        public init(workspaceURL: URL, appBundleURL: URL, metadata: IPAMetadata) {
            self.workspaceURL = workspaceURL
            self.appBundleURL = appBundleURL
            self.metadata = metadata
        }
    }

    public init() {}

    /// Validates the archive, extracts it, and locates the single `.app` payload.
    public func prepare(ipaURL: URL, workspaceRoot: URL? = nil) throws -> PreparedIPA {
        try IPAFileValidator.validate(ipaURL)

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: ipaURL.path) else {
            throw OmnistoreError.invalidIPA("The selected file no longer exists.")
        }

        let root = workspaceRoot ?? fileManager.temporaryDirectory
        do {
            if !fileManager.fileExists(atPath: root.path) {
                try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            }
        } catch {
            throw OmnistoreError.storage("Could not create the IPA workspace: \(error.localizedDescription)")
        }

        let workspace = root.appendingPathComponent("OmniStore-\(UUID().uuidString)", isDirectory: true)
        do {
            try fileManager.createDirectory(at: workspace, withIntermediateDirectories: true)
        } catch {
            throw OmnistoreError.storage("Could not create the IPA workspace: \(error.localizedDescription)")
        }

        do {
            try validateArchive(at: ipaURL)
            do {
                try fileManager.unzipItem(at: ipaURL, to: workspace)
            } catch {
                throw OmnistoreError.invalidIPA("Extraction failed: \(error.localizedDescription)")
            }

            let payloadURL = workspace.appendingPathComponent("Payload", isDirectory: true)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: payloadURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                throw OmnistoreError.invalidIPA("The archive has no Payload directory.")
            }

            let payloadContents: [URL]
            do {
                payloadContents = try fileManager.contentsOfDirectory(
                    at: payloadURL,
                    includingPropertiesForKeys: [.isDirectoryKey]
                )
            } catch {
                throw OmnistoreError.invalidIPA("Could not read the Payload directory: \(error.localizedDescription)")
            }

            let appBundles = payloadContents.filter { $0.pathExtension.lowercased() == "app" }
            guard let appBundleURL = appBundles.first else {
                throw OmnistoreError.invalidIPA("The Payload directory does not contain an .app bundle.")
            }
            guard appBundles.count == 1 else {
                throw OmnistoreError.invalidIPA("The archive contains more than one .app bundle.")
            }

            let metadata = try readMetadata(from: appBundleURL)
            return PreparedIPA(workspaceURL: workspace, appBundleURL: appBundleURL, metadata: metadata)
        } catch {
            discard(workspace: workspace)
            if let known = error as? OmnistoreError {
                throw known
            }
            throw OmnistoreError.invalidIPA(error.localizedDescription)
        }
    }

    /// Repackages a signed `.app` bundle as an IPA with a standard `Payload/` root.
    public func package(appBundleURL: URL, to outputURL: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: appBundleURL.path) else {
            throw OmnistoreError.packagingMissingApp()
        }

        let payloadURL = appBundleURL.deletingLastPathComponent()
        let outputDirectory = outputURL.deletingLastPathComponent()

        do {
            if !fileManager.fileExists(atPath: outputDirectory.path) {
                try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            }
            if fileManager.fileExists(atPath: outputURL.path) {
                try fileManager.removeItem(at: outputURL)
            }
            try fileManager.zipItem(
                at: payloadURL,
                to: outputURL,
                shouldKeepParent: true,
                compressionMethod: .deflate
            )
        } catch {
            if fileManager.fileExists(atPath: outputURL.path) {
                do {
                    try fileManager.removeItem(at: outputURL)
                } catch {
                    // The original packaging error is more useful than a cleanup failure.
                }
            }
            throw OmnistoreError.storage("Could not create the signed IPA: \(error.localizedDescription)")
        }
    }

    public func discard(workspace: URL) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: workspace.path) else { return }
        do {
            try fileManager.removeItem(at: workspace)
        } catch {
            // Workspaces live in the temporary directory and are best-effort cleanup.
        }
    }

    // MARK: - Archive Validation

    private func validateArchive(at ipaURL: URL) throws {
        let archive: Archive
        do {
            archive = try Archive(url: ipaURL, accessMode: .read)
        } catch {
            throw OmnistoreError.invalidIPA("The selected file is not a readable ZIP archive.")
        }

        var entryCount = 0
        var foundPayloadEntry = false

        for entry in archive {
            entryCount += 1
            let path = entry.path
            guard !path.isEmpty else { continue }
            guard !path.hasPrefix("/"), !path.contains("\\"), !path.contains("\0") else {
                throw OmnistoreError.invalidIPA("The archive contains an unsafe path.")
            }

            let components = path.split(separator: "/", omittingEmptySubsequences: true)
            guard !components.contains(where: { $0 == ".." }) else {
                throw OmnistoreError.invalidIPA("The archive attempts to write outside of its workspace.")
            }

            if path.hasPrefix("Payload/") {
                foundPayloadEntry = true
            }
        }

        guard entryCount > 0 else {
            throw OmnistoreError.invalidIPA("The archive is empty.")
        }
        guard foundPayloadEntry else {
            throw OmnistoreError.invalidIPA("The archive does not contain a Payload folder.")
        }
    }

    // MARK: - Bundle Metadata

    private func readMetadata(from appBundleURL: URL) throws -> IPAMetadata {
        let fileManager = FileManager.default
        let infoURL = appBundleURL.appendingPathComponent("Info.plist")
        guard fileManager.fileExists(atPath: infoURL.path) else {
            throw OmnistoreError.invalidIPA("The app bundle has no Info.plist.")
        }

        let infoData: Data
        do {
            infoData = try Data(contentsOf: infoURL)
        } catch {
            throw OmnistoreError.invalidIPA("Could not read Info.plist: \(error.localizedDescription)")
        }

        let plist: [String: Any]
        do {
            let parsed = try PropertyListSerialization.propertyList(from: infoData, options: [], format: nil)
            guard let dictionary = parsed as? [String: Any] else {
                throw OmnistoreError.invalidIPA("Info.plist is not a dictionary.")
            }
            plist = dictionary
        } catch let known as OmnistoreError {
            throw known
        } catch {
            throw OmnistoreError.invalidIPA("Could not parse Info.plist: \(error.localizedDescription)")
        }

        guard let bundleIdentifier = (plist["CFBundleIdentifier"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !bundleIdentifier.isEmpty else {
            throw OmnistoreError.invalidIPA("The app bundle has no CFBundleIdentifier.")
        }

        let bundleName = appBundleURL.deletingPathExtension().lastPathComponent
        let name = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? bundleName
        let version = (plist["CFBundleShortVersionString"] as? String)
            ?? (plist["CFBundleVersion"] as? String)
            ?? "1.0"

        return IPAMetadata(
            bundleIdentifier: bundleIdentifier,
            name: name.isEmpty ? bundleName : name,
            version: version,
            buildNumber: plist["CFBundleVersion"] as? String,
            minimumOSVersion: plist["MinimumOSVersion"] as? String,
            iconData: loadIconData(appBundleURL: appBundleURL, plist: plist)
        )
    }

    private func loadIconData(appBundleURL: URL, plist: [String: Any]) -> Data? {
        let fileManager = FileManager.default
        var iconNames: [String] = []

        for key in ["CFBundleIcons", "CFBundleIcons~ipad"] {
            guard let iconsDictionary = plist[key] as? [String: Any],
                  let primaryIcon = iconsDictionary["CFBundlePrimaryIcon"] as? [String: Any],
                  let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String] else {
                continue
            }
            iconNames.append(contentsOf: iconFiles)
        }

        if let directNames = plist["CFBundleIconFiles"] as? [String] {
            iconNames.append(contentsOf: directNames)
        }
        if let directName = plist["CFBundleIconFile"] as? String {
            iconNames.append(directName)
        }

        var candidates: [String] = []
        for name in iconNames {
            let base = name.replacingOccurrences(of: ".png", with: "")
            candidates.append("\(base)@3x.png")
            candidates.append("\(base)@2x.png")
            candidates.append("\(base).png")
            candidates.append(name)
        }
        candidates.append(contentsOf: [
            "AppIcon60x60@3x.png",
            "AppIcon60x60@2x.png",
            "AppIcon76x76@2x~ipad.png",
            "AppIcon.png",
        ])

        var seen = Set<String>()
        for candidate in candidates where !candidate.isEmpty && !seen.contains(candidate) {
            seen.insert(candidate)
            let url = appBundleURL.appendingPathComponent(candidate)
            guard fileManager.fileExists(atPath: url.path) else { continue }
            do {
                let data = try Data(contentsOf: url)
                if !data.isEmpty {
                    return data
                }
            } catch {
                continue
            }
        }

        let rootContents: [URL]
        do {
            rootContents = try fileManager.contentsOfDirectory(
                at: appBundleURL,
                includingPropertiesForKeys: nil
            )
        } catch {
            return nil
        }

        for url in rootContents
        where url.pathExtension.lowercased() == "png"
            && url.lastPathComponent.lowercased().contains("appicon") {
            do {
                let data = try Data(contentsOf: url)
                if !data.isEmpty {
                    return data
                }
            } catch {
                continue
            }
        }

        return nil
    }
}

private extension OmnistoreError {
    static func packagingMissingApp() -> OmnistoreError {
        .signing("The signed app bundle disappeared before packaging.")
    }
}
