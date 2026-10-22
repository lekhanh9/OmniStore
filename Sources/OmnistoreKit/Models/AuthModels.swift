//
//  AuthModels.swift
//  OmnistoreKit
//

import Foundation

public enum AuthPhase: String, Sendable, Equatable {
    case signedOut
    case signingIn
    case awaitingTwoFactor
    case verifyingTwoFactor
    case signedIn
}

public enum CertificatePreparationState: Sendable, Equatable {
    case idle
    case preparing
    case failed(String)
}

public struct AppleTeamSummary: Identifiable, Sendable, Equatable {
    public var id: String { teamID }

    public let teamID: String
    public let name: String
    public let isFreeAccount: Bool

    public init(teamID: String, name: String, isFreeAccount: Bool) {
        self.teamID = teamID
        self.name = name
        self.isFreeAccount = isFreeAccount
    }
}

public struct SignedInAccount: Sendable, Equatable {
    public let appleID: String
    public let team: AppleTeamSummary

    public init(appleID: String, team: AppleTeamSummary) {
        self.appleID = appleID
        self.team = team
    }
}

public struct CertificateSummary: Sendable, Equatable {
    public let teamID: String
    public let teamName: String
    public let issuedAt: Date
    public let p12Path: String
    public let certificatePath: String
    public let profileCount: Int

    public init(
        teamID: String,
        teamName: String,
        issuedAt: Date,
        p12Path: String,
        certificatePath: String,
        profileCount: Int
    ) {
        self.teamID = teamID
        self.teamName = teamName
        self.issuedAt = issuedAt
        self.p12Path = p12Path
        self.certificatePath = certificatePath
        self.profileCount = profileCount
    }
}

public struct StoredIdentityMetadata: Codable, Sendable, Equatable {
    public let appleID: String
    public let teamID: String
    public let teamName: String
    public let certificateID: String
    public let certificateSerialNumber: String?
    public let issuedAt: Date

    public init(
        appleID: String,
        teamID: String,
        teamName: String,
        certificateID: String,
        certificateSerialNumber: String?,
        issuedAt: Date
    ) {
        self.appleID = appleID
        self.teamID = teamID
        self.teamName = teamName
        self.certificateID = certificateID
        self.certificateSerialNumber = certificateSerialNumber
        self.issuedAt = issuedAt
    }
}

public struct StoredIdentity: Sendable, Equatable {
    public let metadata: StoredIdentityMetadata
    public let p12Data: Data
    public let certificateDER: Data

    public init(metadata: StoredIdentityMetadata, p12Data: Data, certificateDER: Data) {
        self.metadata = metadata
        self.p12Data = p12Data
        self.certificateDER = certificateDER
    }
}

public struct SigningAssets: Sendable {
    public let bundleIdentifier: String
    public let certificateDER: Data
    public let privateKeyDER: Data
    public let provisioningProfileURL: URL
    public let provisioningProfileExpiration: Date?
    public let certificateID: String
    public let teamID: String

    public init(
        bundleIdentifier: String,
        certificateDER: Data,
        privateKeyDER: Data,
        provisioningProfileURL: URL,
        provisioningProfileExpiration: Date?,
        certificateID: String,
        teamID: String
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.certificateDER = certificateDER
        self.privateKeyDER = privateKeyDER
        self.provisioningProfileURL = provisioningProfileURL
        self.provisioningProfileExpiration = provisioningProfileExpiration
        self.certificateID = certificateID
        self.teamID = teamID
    }
}
