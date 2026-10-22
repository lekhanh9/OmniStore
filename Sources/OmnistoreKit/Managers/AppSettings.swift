//
//  AppSettings.swift
//  OmnistoreKit
//
//  User-configurable Anisette and Apple client identity settings,
//  persisted in UserDefaults and injected into every Apple request.
//

#if canImport(Combine)
import Combine
import Foundation
import GhostSign

@MainActor
public final class AppSettings: ObservableObject {
    public static let defaultUserAgent = AppleClientConfiguration.defaultUserAgent
    public static let defaultClientInfo = AppleClientConfiguration.defaultClientInfo

    @Published public var anisetteServerURL: String {
        didSet {
            defaults.set(
                anisetteServerURL.trimmingCharacters(in: .whitespacesAndNewlines),
                forKey: OmnistoreConstants.Preferences.anisetteServer
            )
        }
    }

    @Published public var userAgent: String {
        didSet {
            defaults.set(
                userAgent.trimmingCharacters(in: .whitespacesAndNewlines),
                forKey: OmnistoreConstants.Preferences.userAgent
            )
        }
    }

    @Published public var clientInfo: String {
        didSet {
            defaults.set(
                clientInfo.trimmingCharacters(in: .whitespacesAndNewlines),
                forKey: OmnistoreConstants.Preferences.clientInfo
            )
        }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.anisetteServerURL = defaults.string(forKey: OmnistoreConstants.Preferences.anisetteServer)
            ?? OmnistoreConstants.defaultAnisetteServer
        self.userAgent = defaults.string(forKey: OmnistoreConstants.Preferences.userAgent) ?? ""
        self.clientInfo = defaults.string(forKey: OmnistoreConstants.Preferences.clientInfo) ?? ""
    }

    /// Configuration handed to GhostSign; blank fields fall back to Apple's defaults.
    public var clientConfiguration: AppleClientConfiguration {
        AppleClientConfiguration(userAgent: userAgent, clientInfo: clientInfo)
    }

    /// The Anisette URL if it is a usable HTTPS endpoint.
    public var validatedAnisetteServerURL: URL? {
        let trimmed = anisetteServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              url.scheme?.lowercased() == "https",
              let host = url.host,
              !host.isEmpty else {
            return nil
        }
        return url
    }

    public func resetSpoofingHeaders() {
        userAgent = ""
        clientInfo = ""
    }
}
#endif
