//
//  InstalledApp.swift
//  OmnistoreKit
//

import Foundation

public enum AppLifecycleStatus: String, Codable, Sendable, Equatable {
    case active
    case expiringSoon
    case expired

    public var title: String {
        switch self {
        case .active: return "Active"
        case .expiringSoon: return "Expiring soon"
        case .expired: return "Expired"
        }
    }
}

public struct InstalledApp: Codable, Sendable, Equatable, Identifiable {
    public var id: String { bundleIdentifier }

    public let bundleIdentifier: String
    public let name: String
    public let version: String
    public let developerName: String?
    public let installedDate: Date
    public let expirationDate: Date
    public let iconURL: URL?
    public let iconSystemName: String?
    public let appIdId: String?
    public let certificateId: String?
    public let originalIPAFileName: String?

    public init(
        bundleIdentifier: String,
        name: String,
        version: String,
        developerName: String? = nil,
        installedDate: Date = Date(),
        expirationDate: Date = Date().addingTimeInterval(OmnistoreConstants.freeCertificateValidity),
        iconURL: URL? = nil,
        iconSystemName: String? = nil,
        appIdId: String? = nil,
        certificateId: String? = nil,
        originalIPAFileName: String? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.version = version
        self.developerName = developerName
        self.installedDate = installedDate
        self.expirationDate = expirationDate
        self.iconURL = iconURL
        self.iconSystemName = iconSystemName
        self.appIdId = appIdId
        self.certificateId = certificateId
        self.originalIPAFileName = originalIPAFileName
    }

    public var secondsRemaining: TimeInterval {
        expirationDate.timeIntervalSince(Date())
    }

    public var daysRemaining: Int {
        max(0, Int(ceil(secondsRemaining / 86_400)))
    }

    public var isExpired: Bool {
        secondsRemaining <= 0
    }

    public var needsRefresh: Bool {
        secondsRemaining <= OmnistoreConstants.refreshThreshold
    }

    public var status: AppLifecycleStatus {
        if isExpired { return .expired }
        if needsRefresh { return .expiringSoon }
        return .active
    }

    public var isDemo: Bool {
        bundleIdentifier.hasPrefix(OmnistoreConstants.Demo.bundleIdentifierPrefix)
    }

    public static var sampleApps: [InstalledApp] {
        let now = Date()
        return [
            InstalledApp(
                bundleIdentifier: "com.omnistore.demo.solstice",
                name: "Solstice",
                version: "3.4.1",
                developerName: "Northlight Labs",
                installedDate: now.addingTimeInterval(-3 * 86_400),
                expirationDate: now.addingTimeInterval(4 * 86_400),
                iconSystemName: "sun.max.fill"
            ),
            InstalledApp(
                bundleIdentifier: "com.omnistore.demo.tide",
                name: "Tide",
                version: "2.0.8",
                developerName: "Coastal Software",
                installedDate: now.addingTimeInterval(-5 * 86_400),
                expirationDate: now.addingTimeInterval(2 * 86_400),
                iconSystemName: "drop.fill"
            ),
            InstalledApp(
                bundleIdentifier: "com.omnistore.demo.monolith",
                name: "Monolith",
                version: "1.9.0",
                developerName: "Studio Nine",
                installedDate: now.addingTimeInterval(-7 * 86_400),
                expirationDate: now.addingTimeInterval(5 * 86_400),
                iconSystemName: "square.stack.3d.up.fill"
            ),
            InstalledApp(
                bundleIdentifier: "com.omnistore.demo.eclipse",
                name: "Eclipse",
                version: "4.2.0",
                developerName: "Afterdark",
                installedDate: now.addingTimeInterval(-9 * 86_400),
                expirationDate: now.addingTimeInterval(-1 * 86_400),
                iconSystemName: "moon.stars.fill"
            ),
        ]
    }
}
