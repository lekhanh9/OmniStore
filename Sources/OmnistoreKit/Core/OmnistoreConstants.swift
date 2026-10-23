//
//  OmnistoreConstants.swift
//  OmnistoreKit
//

import Foundation

public enum OmnistoreConstants {
    public static let appName = "OmniStore"
    public static let appVersion = "1.0.0"

    public static let freeCertificateValidity: TimeInterval = 7 * 86_400
    public static let refreshThreshold: TimeInterval = 2 * 86_400

    public static let rootDirectoryName = "Omnistore"
    public static let profilesDirectoryName = "Profiles"
    public static let libraryDirectoryName = "Library"
    public static let iconsDirectoryName = "Icons"
    public static let installedAppsFileName = "installed-apps.json"
    public static let identityFileName = "identity.p12"
    public static let certificateFileName = "identity.cer"
    public static let identityMetadataFileName = "identity.json"
    public static let provisioningProfileExtension = "mobileprovision"

    public static let defaultAnisetteServer = "https://ani.sidestore.io"

    public static let pairingDirectoryName = "Pairing"
    public static let pairingFileName = "pairing.mobiledevicepairing"
    public static let defaultVPNPeerIP = "10.7.0.1"

    public enum Preferences {
        public static let appleID = "omnistore.appleID"
        public static let anisetteServer = "omnistore.anisetteServer"
        public static let selectedTeamID = "omnistore.selectedTeamID"
        public static let deviceUDID = "omnistore.deviceUDID"
        public static let mockInstallDelay = "omnistore.mockInstallDelay"
        public static let mockInstallFailure = "omnistore.mockInstallFailure"
    }

    public enum Demo {
        public static let bundleIdentifierPrefix = "com.omnistore.demo."
    }
}
