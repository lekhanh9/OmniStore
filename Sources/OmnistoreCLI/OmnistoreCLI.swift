//
//  OmnistoreCLI.swift
//  OmnistoreCLI
//
//  Lightweight Linux/macOS development harness for the cross-platform core.
//

import Foundation
import OmnistoreKit

@main
struct OmnistoreCLI {
    static func main() async {
        let arguments = CommandLine.arguments.dropFirst()
        guard let command = arguments.first?.lowercased() else {
            printUsage()
            return
        }

        switch command {
        case "info":
            await printInfo()
        case "list":
            await printLibrary()
        case "inspect":
            let remaining = Array(arguments.dropFirst())
            guard let path = remaining.first else {
                print("Usage: omnistore inspect <path-to.ipa>")
                return
            }
            await inspectIPA(path: path)
        case "help", "--help", "-h":
            printUsage()
        default:
            print("Unknown command: \(command)")
            printUsage()
        }
    }

    private static func printInfo() async {
        let library = LibraryStore()
        let apps = await loadApps(from: library)
        print("""
        OmniStore \(OmnistoreConstants.appVersion)
        ----------------------------------------
        Storage:          \(LibraryStore.defaultBaseDirectory().deletingLastPathComponent().path)
        Apple ID:         not persisted (in-memory sessions only)
        Signing identity: \(IdentityStore.defaultBaseDirectory().path)
        Installer:        MockInstaller (Minimuxer bridge pending)
        Installed apps:   \(apps.count)
        Security:         zero Keychain, Documents-only credentials
        """)
    }

    private static func printLibrary() async {
        let apps = await loadApps(from: LibraryStore())
        guard !apps.isEmpty else {
            print("No apps are installed in the OmniStore library.")
            return
        }

        print("Installed apps (\(apps.count))")
        for app in apps {
            let remaining = app.isExpired ? "expired" : "\(app.daysRemaining)d remaining"
            print("  \(app.name) \(app.version)  \(app.bundleIdentifier)  [\(remaining)]")
        }
    }

    private static func inspectIPA(path: String) async {
        let service = IPAService()
        let url = URL(fileURLWithPath: path)
        do {
            let prepared = try await service.prepare(ipaURL: url)
            print("Name:       \(prepared.metadata.name)")
            print("Bundle ID:  \(prepared.metadata.bundleIdentifier)")
            print("Version:    \(prepared.metadata.version)")
            print("Executable: \(prepared.appBundleURL.lastPathComponent)")
            if let iconData = prepared.metadata.iconData {
                print("Icon:       \(iconData.count) bytes")
            } else {
                print("Icon:       not found")
            }
            await service.discard(workspace: prepared.workspaceURL)
        } catch {
            print("Inspection failed: \(error.localizedDescription)")
        }
    }

    private static func loadApps(from store: LibraryStore) async -> [InstalledApp] {
        do {
            return try await store.load()
        } catch {
            print("Could not read the library: \(error.localizedDescription)")
            return []
        }
    }

    private static func printUsage() {
        print("""
        OmniStore CLI

        Usage:
          omnistore info             Show storage paths and runtime configuration
          omnistore list             List the persisted app library
          omnistore inspect <ipa>    Validate and inspect a local IPA archive
          omnistore help             Show this help
        """)
    }
}
