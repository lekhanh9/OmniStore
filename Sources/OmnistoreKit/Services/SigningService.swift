//
//  SigningService.swift
//  OmnistoreKit
//
//  Bridges Omnistore to GhostCode's Mach-O / bundle signer.
//

import Foundation
import GhostCode

public struct SigningService: Sendable {
    public init() {}

    /// Signs a fully extracted `.app` bundle. When assets are `nil`, the
    /// bundle is ad-hoc signed for the mock/demo installation path.
    public func sign(appBundleURL: URL, assets: SigningAssets?) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: appBundleURL.path) else {
            throw OmnistoreError.signing("The extracted app bundle is missing.")
        }

        let signer = GhostSigner()

        do {
            if let assets {
                guard fileManager.fileExists(atPath: assets.provisioningProfileURL.path) else {
                    throw OmnistoreError.signing("The provisioning profile is missing from Documents.")
                }

                try signer.signBundle(
                    appURL: appBundleURL,
                    provisioningProfileURL: assets.provisioningProfileURL,
                    rawCertificate: assets.certificateDER,
                    rawPrivateKey: assets.privateKeyDER
                )
            } else {
                let bundleIdentifier = readBundleIdentifier(from: appBundleURL) ?? "com.omnistore.adhoc"
                let entitlements: [String: Any] = [
                    "get-task-allow": true,
                    "application-identifier": bundleIdentifier,
                ]

                try signer.signBundle(
                    appURL: appBundleURL,
                    entitlements: entitlements
                )
            }
        } catch let known as OmnistoreError {
            throw known
        } catch {
            throw OmnistoreError.signing(error.localizedDescription)
        }
    }

    private func readBundleIdentifier(from appBundleURL: URL) -> String? {
        let infoURL = appBundleURL.appendingPathComponent("Info.plist")
        do {
            let data = try Data(contentsOf: infoURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            let dictionary = plist as? [String: Any]
            let identifier = dictionary?["CFBundleIdentifier"] as? String
            let trimmed = identifier?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let trimmed, !trimmed.isEmpty else { return nil }
            return trimmed
        } catch {
            return nil
        }
    }
}
