//
//  AppSettings.swift
//  OmnistoreKit
//
//  User-configurable Anisette server setting, persisted in UserDefaults.
//  All Apple client identity headers are taken verbatim from the
//  Anisette server response, so nothing is spoofed locally.
//

#if canImport(Combine)
import Combine
import Foundation

@MainActor
public final class AppSettings: ObservableObject {
    @Published public var anisetteServerURL: String {
        didSet {
            defaults.set(
                anisetteServerURL.trimmingCharacters(in: .whitespacesAndNewlines),
                forKey: OmnistoreConstants.Preferences.anisetteServer
            )
        }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.anisetteServerURL = defaults.string(forKey: OmnistoreConstants.Preferences.anisetteServer)
            ?? OmnistoreConstants.defaultAnisetteServer
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
}
#endif
