//
//  LibraryStore.swift
//  OmnistoreKit
//

import Foundation

public actor LibraryStore {
    public let baseDirectory: URL
    public let iconsDirectory: URL

    private let recordsURL: URL

    public init(baseDirectory: URL? = nil) {
        let root = baseDirectory ?? Self.defaultBaseDirectory()
        self.baseDirectory = root
        self.iconsDirectory = root.appendingPathComponent(OmnistoreConstants.iconsDirectoryName, isDirectory: true)
        self.recordsURL = root.appendingPathComponent(OmnistoreConstants.installedAppsFileName)
    }

    public nonisolated static func defaultBaseDirectory() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents", isDirectory: true)
        return documentsURL
            .appendingPathComponent(OmnistoreConstants.rootDirectoryName, isDirectory: true)
            .appendingPathComponent(OmnistoreConstants.libraryDirectoryName, isDirectory: true)
    }

    public func load() throws -> [InstalledApp] {
        guard FileManager.default.fileExists(atPath: recordsURL.path) else {
            return []
        }

        let data: Data
        do {
            data = try Data(contentsOf: recordsURL)
        } catch {
            throw OmnistoreError.library("Could not read installed apps: \(error.localizedDescription)")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode([InstalledApp].self, from: data)
        } catch {
            throw OmnistoreError.library("Could not decode installed apps: \(error.localizedDescription)")
        }
    }

    @discardableResult
    public func upsert(_ app: InstalledApp) throws -> [InstalledApp] {
        var apps = try load()
        if let index = apps.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            apps[index] = app
        } else {
            apps.append(app)
        }
        try save(apps)
        return apps
    }

    @discardableResult
    public func remove(bundleIdentifier: String) throws -> [InstalledApp] {
        var apps = try load()
        apps.removeAll { $0.bundleIdentifier == bundleIdentifier }
        try save(apps)
        return apps
    }

    public func saveIcon(_ data: Data, bundleIdentifier: String) throws -> URL {
        try ensureDirectory(iconsDirectory, label: "icons")
        let fileName = try safeFileName(bundleIdentifier).appending(".png")
        let url = iconsDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw OmnistoreError.library("Could not save the app icon: \(error.localizedDescription)")
        }
        return url
    }

    public func removeIcon(at url: URL?) throws {
        guard let url else { return }
        let standardized = url.standardizedFileURL
        let iconsRoot = iconsDirectory.standardizedFileURL
        guard standardized.path.hasPrefix(iconsRoot.path + "/") else { return }
        guard FileManager.default.fileExists(atPath: standardized.path) else { return }

        do {
            try FileManager.default.removeItem(at: standardized)
        } catch {
            throw OmnistoreError.library("Could not remove the app icon: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func save(_ apps: [InstalledApp]) throws {
        try ensureDirectory(baseDirectory, label: "library")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data: Data
        do {
            data = try encoder.encode(apps)
        } catch {
            throw OmnistoreError.library("Could not encode installed apps: \(error.localizedDescription)")
        }

        do {
            try data.write(to: recordsURL, options: .atomic)
        } catch {
            throw OmnistoreError.library("Could not write installed apps: \(error.localizedDescription)")
        }
    }

    private func ensureDirectory(_ url: URL, label: String) throws {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw OmnistoreError.library("Could not create the \(label) directory: \(error.localizedDescription)")
        }
    }

    private func safeFileName(_ rawValue: String) throws -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
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
        return sanitized
    }
}
