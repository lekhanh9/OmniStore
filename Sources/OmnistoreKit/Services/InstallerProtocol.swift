//
//  InstallerProtocol.swift
//  OmnistoreKit
//

import Foundation

/// A device installer. `MockInstaller` is the current implementation;
/// a Minimuxer-backed implementation can be added without changing the UI.
public protocol InstallerProtocol: Sendable {
    var isMock: Bool { get }

    func installApp(
        ipaURL: URL,
        progressHandler: (@Sendable (Double) -> Void)?
    ) async throws

    func uninstallApp(bundleIdentifier: String) async throws
}
