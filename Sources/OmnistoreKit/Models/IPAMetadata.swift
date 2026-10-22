//
//  IPAMetadata.swift
//  OmnistoreKit
//

import Foundation

public struct IPAMetadata: Sendable, Equatable {
    public let bundleIdentifier: String
    public let name: String
    public let version: String
    public let buildNumber: String?
    public let minimumOSVersion: String?
    public let iconData: Data?

    public init(
        bundleIdentifier: String,
        name: String,
        version: String,
        buildNumber: String?,
        minimumOSVersion: String?,
        iconData: Data?
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.version = version
        self.buildNumber = buildNumber
        self.minimumOSVersion = minimumOSVersion
        self.iconData = iconData
    }
}
