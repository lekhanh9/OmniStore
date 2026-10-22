//
//  AuthManager.swift
//  OmnistoreKit
//
//  ObservableObject facade over GhostSign: Apple ID SRP login, 2FA,
//  certificate issuance and provisioning-profile creation.
//  Credentials are never persisted; only certificates/profiles are saved in Documents.
//

#if canImport(Combine)
import Combine
import Foundation
import GhostSign

@MainActor
public final class AuthManager: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var phase: AuthPhase = .signedOut
    @Published public var appleID: String
    @Published public var password: String = ""
    @Published public var twoFactorCode: String = ""
    @Published public var anisetteServerURL: String
    @Published public var deviceUDID: String

    @Published public private(set) var teams: [AppleTeamSummary] = []
    @Published public private(set) var selectedTeamID: String?
    @Published public private(set) var account: SignedInAccount?
    @Published public private(set) var certificateSummary: CertificateSummary?
    @Published public private(set) var certificatePreparation: CertificatePreparationState = .idle
    @Published public private(set) var storedAppleID: String?
    @Published public private(set) var lastError: String?

    // MARK: - Private State

    private struct KeyMaterial: Sendable {
        let csrDER: Data
        let privateKeyDER: Data
    }

    private let identityStore: IdentityStore
    private let defaults: UserDefaults

    private var session: AuthSession?
    private var portalClient: DeveloperPortalClient?
    private var pendingTwoFactor: TwoFactorContext?

    // MARK: - Lifecycle

    public init(
        identityStore: IdentityStore = IdentityStore(),
        defaults: UserDefaults = .standard
    ) {
        self.identityStore = identityStore
        self.defaults = defaults
        self.appleID = defaults.string(forKey: OmnistoreConstants.Preferences.appleID) ?? ""
        self.anisetteServerURL = defaults.string(forKey: OmnistoreConstants.Preferences.anisetteServer)
            ?? OmnistoreConstants.defaultAnisetteServer
        self.deviceUDID = defaults.string(forKey: OmnistoreConstants.Preferences.deviceUDID) ?? ""
        self.selectedTeamID = defaults.string(forKey: OmnistoreConstants.Preferences.selectedTeamID)

        Task { [weak self] in
            await self?.reloadStoredCertificate()
        }
    }

    // MARK: - Derived State

    public var isSignedIn: Bool {
        phase == .signedIn
    }

    public var isBusy: Bool {
        phase == .signingIn || phase == .awaitingTwoFactor || phase == .verifyingTwoFactor
    }

    public var selectedTeam: AppleTeamSummary? {
        guard let selectedTeamID else { return nil }
        return teams.first { $0.teamID == selectedTeamID }
    }

    public var hasStoredCertificate: Bool {
        certificateSummary != nil
    }

    public var isPreparingCertificate: Bool {
        certificatePreparation == .preparing
    }

    // MARK: - Sign In

    public func signIn() async {
        guard phase == .signedOut else { return }
        lastError = nil

        let normalizedID = appleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedID.isEmpty, !password.isEmpty else {
            lastError = "Enter your Apple ID and password to continue."
            return
        }
        guard let serverURL = validatedAnisetteURL() else { return }

        appleID = normalizedID
        savePreferences()
        phase = .signingIn
        let secret = password

        do {
            let auth = AppleAuth(anisetteProvider: RemoteAnisetteProvider(serverURL: serverURL))
            let result = try await auth.startLogin(appleID: normalizedID, password: secret)

            switch result {
            case .authenticated(let session):
                password = ""
                await completeSignIn(session: session)
            case .requires2FA(let context):
                password = ""
                pendingTwoFactor = context
                twoFactorCode = ""
                phase = .awaitingTwoFactor
            }
        } catch let authError as AppleAuthError {
            if case .requiresTwoFactor(let context) = authError {
                password = ""
                pendingTwoFactor = context
                twoFactorCode = ""
                phase = .awaitingTwoFactor
            } else {
                failSignIn(message(for: authError))
            }
        } catch {
            failSignIn(message(for: error))
        }
    }

    public func submitTwoFactorCode() async {
        guard phase == .awaitingTwoFactor, let context = pendingTwoFactor else { return }
        let code = twoFactorCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count >= 6 else {
            lastError = "Enter the six-digit verification code from your trusted device."
            return
        }
        guard let serverURL = validatedAnisetteURL() else { return }

        lastError = nil
        phase = .verifyingTwoFactor

        do {
            let auth = AppleAuth(anisetteProvider: RemoteAnisetteProvider(serverURL: serverURL))
            let session = try await auth.submit2FACode(code: code, context: context)
            pendingTwoFactor = nil
            twoFactorCode = ""
            await completeSignIn(session: session)
        } catch {
            phase = .awaitingTwoFactor
            lastError = message(for: error)
        }
    }

    public func cancelTwoFactor() {
        guard phase == .awaitingTwoFactor || phase == .verifyingTwoFactor else { return }
        pendingTwoFactor = nil
        twoFactorCode = ""
        password = ""
        phase = .signedOut
    }

    public func signOut() {
        session = nil
        portalClient = nil
        pendingTwoFactor = nil
        teams = []
        account = nil
        selectedTeamID = nil
        password = ""
        twoFactorCode = ""
        phase = .signedOut
        lastError = nil
    }

    public func selectTeam(_ teamID: String) {
        guard let team = teams.first(where: { $0.teamID == teamID }) else { return }
        selectedTeamID = team.teamID
        session?.teamID = team.teamID
        account = SignedInAccount(appleID: appleID, team: team)
        defaults.set(team.teamID, forKey: OmnistoreConstants.Preferences.selectedTeamID)
    }

    public func savePreferences() {
        defaults.set(appleID.trimmingCharacters(in: .whitespacesAndNewlines), forKey: OmnistoreConstants.Preferences.appleID)
        defaults.set(anisetteServerURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: OmnistoreConstants.Preferences.anisetteServer)
        defaults.set(deviceUDID.trimmingCharacters(in: .whitespacesAndNewlines), forKey: OmnistoreConstants.Preferences.deviceUDID)
        if let selectedTeamID {
            defaults.set(selectedTeamID, forKey: OmnistoreConstants.Preferences.selectedTeamID)
        }
    }

    public func clearError() {
        lastError = nil
    }

    // MARK: - Session Completion

    private func completeSignIn(session: AuthSession) async {
        self.session = session
        let client = DeveloperPortalClient(session: session)
        portalClient = client

        do {
            let fetchedTeams = try await client.listTeams()
            guard !fetchedTeams.isEmpty else {
                throw OmnistoreError.authentication("This Apple ID is not a member of a developer team.")
            }

            teams = fetchedTeams.map {
                AppleTeamSummary(
                    teamID: $0.teamId,
                    name: $0.name,
                    isFreeAccount: $0.isFreeAccount
                )
            }

            let savedTeamID = selectedTeamID
            let storedCertTeamID = certificateSummary?.teamID
            let preferred = fetchedTeams.first { $0.teamId == savedTeamID }
                ?? fetchedTeams.first { $0.teamId == storedCertTeamID }
                ?? fetchedTeams.first { $0.isFreeAccount }
                ?? fetchedTeams.first

            guard let preferred else {
                throw OmnistoreError.authentication("No usable developer team was found.")
            }

            selectedTeamID = preferred.teamId
            self.session?.teamID = preferred.teamId
            defaults.set(preferred.teamId, forKey: OmnistoreConstants.Preferences.selectedTeamID)
            account = SignedInAccount(
                appleID: appleID,
                team: AppleTeamSummary(
                    teamID: preferred.teamId,
                    name: preferred.name,
                    isFreeAccount: preferred.isFreeAccount
                )
            )
            phase = .signedIn
            lastError = nil

            await reloadStoredCertificate()
            if certificateSummary == nil {
                await prepareCertificate()
            }
        } catch {
            failSignIn(message(for: error))
        }
    }

    private func failSignIn(_ reason: String) {
        lastError = reason
        session = nil
        portalClient = nil
        pendingTwoFactor = nil
        phase = .signedOut
        password = ""
        twoFactorCode = ""
    }

    // MARK: - Certificates

    public func reloadStoredCertificate() async {
        do {
            guard let identity = try await identityStore.loadIdentity() else {
                certificateSummary = nil
                storedAppleID = nil
                return
            }

            var profileCount = 0
            do {
                profileCount = try await identityStore.profileCount()
            } catch {
                profileCount = 0
            }

            let paths = await identityStore.identityPaths()
            certificateSummary = CertificateSummary(
                teamID: identity.metadata.teamID,
                teamName: identity.metadata.teamName,
                issuedAt: identity.metadata.issuedAt,
                p12Path: paths.p12,
                certificatePath: paths.certificate,
                profileCount: profileCount
            )
            storedAppleID = identity.metadata.appleID
        } catch {
            certificateSummary = nil
            lastError = message(for: error)
        }
    }

    public func prepareCertificate() async {
        guard phase == .signedIn, let client = portalClient, let team = selectedTeam else {
            lastError = "Sign in to your Apple ID before preparing a signing certificate."
            return
        }
        guard certificatePreparation != .preparing else { return }

        lastError = nil
        certificatePreparation = .preparing

        do {
            if let existing = try await identityStore.loadIdentity() {
                guard existing.metadata.teamID == team.teamID else {
                    throw OmnistoreError.provisioning(
                        "A certificate for team “\(existing.metadata.teamName)” is already stored. Remove it before preparing a certificate for “\(team.name)”."
                    )
                }
                await reloadStoredCertificate()
                certificatePreparation = .idle
                return
            }

            let accountID = appleID
            let material = try await Self.generateKeyMaterial(accountID: accountID, team: team)
            let certificate = try await client.addCertificate(
                csrDER: material.csrDER,
                teamId: team.teamID
            )

            guard !certificate.certContent.isEmpty else {
                throw OmnistoreError.provisioning("Apple returned an empty development certificate.")
            }
            guard let certificateID = certificate.certificateId, !certificateID.isEmpty else {
                throw OmnistoreError.provisioning("Apple did not return a certificate identifier.")
            }

            let friendlyName = "OmniStore: \(accountID)"
            let p12Data = try await Self.exportP12(
                certificateDER: certificate.certContent,
                privateKeyDER: material.privateKeyDER,
                friendlyName: friendlyName
            )

            let metadata = StoredIdentityMetadata(
                appleID: accountID,
                teamID: team.teamID,
                teamName: team.name,
                certificateID: certificateID,
                certificateSerialNumber: certificate.serialNumber,
                issuedAt: Date()
            )

            try await identityStore.saveIdentity(
                p12Data: p12Data,
                certificateDER: certificate.certContent,
                metadata: metadata
            )

            await reloadStoredCertificate()
            certificatePreparation = .idle
        } catch {
            let reason = message(for: error)
            certificatePreparation = .failed(reason)
            lastError = reason
        }
    }

    public func removeCertificateAndProfiles() async {
        do {
            try await identityStore.removeCredentials()
            certificatePreparation = .idle
            await reloadStoredCertificate()
            lastError = nil
        } catch {
            lastError = message(for: error)
        }
    }

    // MARK: - Provisioning for Installation

    public func signingAssets(
        bundleIdentifier: String,
        appName: String,
        deviceUDID: String
    ) async throws -> SigningAssets {
        guard phase == .signedIn, let client = portalClient, let team = selectedTeam else {
            throw OmnistoreError.authentication("Sign in to your Apple ID before installing a signed app.")
        }
        if session?.isExpired == true {
            signOut()
            throw OmnistoreError.authentication("Your Apple ID session expired. Sign in again.")
        }

        let trimmedUDID = deviceUDID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedUDID = try Self.validateUDID(trimmedUDID)
        self.deviceUDID = trimmedUDID
        savePreferences()

        var stored = try await identityStore.loadIdentity()
        if stored == nil {
            await prepareCertificate()
            stored = try await identityStore.loadIdentity()
        }

        guard let identity = stored else {
            if case .failed(let reason) = certificatePreparation {
                throw OmnistoreError.provisioning(reason)
            }
            throw OmnistoreError.provisioning("No signing certificate is available. Prepare one in Settings and try again.")
        }
        guard identity.metadata.teamID == team.teamID else {
            throw OmnistoreError.provisioning(
                "The stored certificate belongs to “\(identity.metadata.teamName)”, not “\(team.name)”. Remove it in Settings and prepare a new certificate."
            )
        }
        guard !identity.metadata.certificateID.isEmpty else {
            throw OmnistoreError.provisioning("The stored certificate has no Apple certificate identifier.")
        }

        let rawIdentity: RawIdentity
        do {
            rawIdentity = try PKCS12Parser.extract(p12Data: identity.p12Data, password: "")
        } catch {
            throw OmnistoreError.signing("Could not open the saved .p12 identity: \(error.localizedDescription)")
        }

        do {
            let devices = try await client.listDevices(teamId: team.teamID)
            let device: DeveloperDevice
            if let existing = devices.first(where: { Self.canonicalUDID($0.udid) == normalizedUDID }) {
                device = existing
            } else {
                device = try await client.addDevice(name: "OmniStore Device", udid: trimmedUDID, teamId: team.teamID)
            }

            let appIDs = try await client.listAppIds(teamId: team.teamID)
            let appID: DeveloperAppId
            if let existing = appIDs.first(where: {
                $0.identifier.caseInsensitiveCompare(bundleIdentifier) == .orderedSame
            }) {
                appID = existing
            } else {
                let trimmedName = String(appName.prefix(40))
                appID = try await client.addAppId(
                    name: trimmedName.isEmpty ? bundleIdentifier : trimmedName,
                    identifier: bundleIdentifier,
                    teamId: team.teamID
                )
            }

            let profiles = try await client.listProvisioningProfiles(teamId: team.teamID)
            var resolvedProfile: DeveloperProvisioningProfile?

            if let reusable = profiles.first(where: {
                Self.profileMatches(
                    $0,
                    bundleIdentifier: bundleIdentifier,
                    appIDID: appID.appIdId,
                    certificateID: identity.metadata.certificateID,
                    udid: normalizedUDID,
                    internalDeviceID: device.deviceId
                )
            }), let profileID = reusable.provisioningProfileId, !profileID.isEmpty {
                do {
                    resolvedProfile = try await client.downloadProvisioningProfile(
                        profileId: profileID,
                        teamId: team.teamID
                    )
                } catch {
                    resolvedProfile = nil
                }
            }

            if resolvedProfile == nil || resolvedProfile?.encodedProfile.isEmpty == true {
                resolvedProfile = try await client.createProvisioningProfile(
                    name: "OmniStore: \(bundleIdentifier)",
                    bundleId: appID.appIdId,
                    certificateId: identity.metadata.certificateID,
                    deviceUDIDs: [trimmedUDID],
                    teamId: team.teamID
                )
            }

            guard let profile = resolvedProfile, !profile.encodedProfile.isEmpty else {
                throw OmnistoreError.provisioning("Apple did not return a provisioning profile.")
            }

            let profileURL = try await identityStore.saveProvisioningProfile(
                profile.encodedProfile,
                bundleIdentifier: bundleIdentifier
            )

            return SigningAssets(
                bundleIdentifier: bundleIdentifier,
                certificateDER: rawIdentity.certificateDER,
                privateKeyDER: rawIdentity.privateKeyDER,
                provisioningProfileURL: profileURL,
                provisioningProfileExpiration: profile.dateExpire,
                certificateID: identity.metadata.certificateID,
                teamID: team.teamID
            )
        } catch let known as OmnistoreError {
            throw known
        } catch {
            throw OmnistoreError.provisioning(message(for: error))
        }
    }

    // MARK: - Helpers

    private func validatedAnisetteURL() -> URL? {
        let trimmed = anisetteServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              url.scheme?.lowercased() == "https",
              let host = url.host,
              !host.isEmpty else {
            lastError = "Enter a valid HTTPS Anisette server URL."
            return nil
        }
        return url
    }

    private static func validateUDID(_ value: String) throws -> String {
        guard value.count >= 20, value.count <= 40 else {
            throw OmnistoreError.invalidConfiguration("Enter your device UDID in Settings. It is required to create a provisioning profile.")
        }
        let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF-")
        guard value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw OmnistoreError.invalidConfiguration("The device UDID contains unexpected characters.")
        }
        return value.lowercased()
    }

    private static func canonicalUDID(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func profileMatches(
        _ profile: DeveloperProvisioningProfile,
        bundleIdentifier: String,
        appIDID: String,
        certificateID: String,
        udid: String,
        internalDeviceID: String?
    ) -> Bool {
        guard profile.status?.lowercased() != "expired" else { return false }
        guard profile.appIdId == appIDID || profile.appIdId == bundleIdentifier else { return false }
        guard (profile.certificateIds ?? []).contains(certificateID) else { return false }

        let deviceIDs = profile.deviceIds ?? []
        let matchesInternalID: Bool
        if let internalDeviceID {
            matchesInternalID = deviceIDs.contains(internalDeviceID)
        } else {
            matchesInternalID = false
        }
        let matchesRawUDID = deviceIDs.contains { canonicalUDID($0) == udid }
        return matchesInternalID || matchesRawUDID
    }

    private nonisolated static func generateKeyMaterial(
        accountID: String,
        team: AppleTeamSummary
    ) async throws -> KeyMaterial {
        try await Task.detached(priority: .userInitiated) {
            let keyPair = try RSAKeyPair()
            let subject = CSRSubject(
                commonName: "OmniStore: \(accountID)",
                country: "US",
                organization: team.name,
                organizationalUnit: team.teamID
            )
            let csr = try CSRGenerator.generateCSR(keyPair: keyPair, subject: subject)
            return KeyMaterial(csrDER: csr.der, privateKeyDER: keyPair.pkcs8DER)
        }.value
    }

    private nonisolated static func exportP12(
        certificateDER: Data,
        privateKeyDER: Data,
        friendlyName: String
    ) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try PKCS12Exporter.export(
                certificateDER: certificateDER,
                privateKeyDER: privateKeyDER,
                password: "",
                friendlyName: friendlyName
            )
        }.value
    }

    private func message(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return error.localizedDescription
    }
}
#endif
