//
//  SettingsView.swift
//  OmniStore
//

import Foundation
import SwiftUI
import OmnistoreKit

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var activeAlert: SettingsAlert?

    var body: some View {
        ZStack {
            AmbientBackground(tint: OmniTheme.lavender)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    header

                    if let error = auth.lastError, !error.isEmpty {
                        OmniErrorBanner(message: error) {
                            auth.clearError()
                        }
                    }

                    AccountSection {
                        activeAlert = .signOut
                    }

                    CertificateSection {
                        activeAlert = .removeCertificate
                    }

                    InstallerSection()

                    StorageSection()

                    AboutSection()
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 116)
            }
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .signOut:
                return Alert(
                    title: Text("Sign out of Apple ID?"),
                    message: Text("The active session is cleared from memory. Your saved certificate and provisioning profiles remain in Documents."),
                    primaryButton: .destructive(Text("Sign Out")) {
                        auth.signOut()
                    },
                    secondaryButton: .cancel()
                )
            case .removeCertificate:
                return Alert(
                    title: Text("Remove signing identity?"),
                    message: Text("This deletes the saved .p12, certificate, and every provisioning profile in Documents. Apps already in your library stay until you remove them."),
                    primaryButton: .destructive(Text("Remove")) {
                        Task {
                            await auth.removeCertificateAndProfiles()
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 13) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(OmniTypography.display(34))
                    .foregroundColor(OmniTheme.primaryText)
                Text("Account, signing, and installer controls.")
                    .font(OmniTypography.body(13))
                    .foregroundColor(OmniTheme.secondaryText)
            }
            Spacer()
            EmptyIconView(symbol: "gearshape.fill", size: 46, tint: OmniTheme.lavender)
        }
    }
}

// MARK: - Account

private struct AccountSection: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var settings: AppSettings
    let onRequestSignOut: () -> Void

    @State private var isAdvancedExpanded = false

    private var canSignIn: Bool {
        !auth.appleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !auth.password.isEmpty
            && !auth.isBusy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            OmniSectionHeader(
                title: "Apple ID",
                subtitle: "A developer account is required for signed installs."
            )

            GlassCard(cornerRadius: 22, padding: 17) {
                VStack(alignment: .leading, spacing: 15) {
                    if auth.isSignedIn {
                        signedInHeader
                        teamSelector
                        signOutButton
                    } else {
                        signInForm
                    }

                    Rectangle()
                        .fill(OmniTheme.hairline)
                        .frame(height: 1)

                    deviceConfiguration
                }
            }
        }
    }

    private var signedInHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(OmniTheme.accent.opacity(0.14))
                Circle()
                    .strokeBorder(OmniTheme.accent.opacity(0.28), lineWidth: 1)
                Image(systemName: "applelogo")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(OmniTheme.accent)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(auth.appleID)
                    .font(OmniTypography.title(14))
                    .foregroundColor(OmniTheme.primaryText)
                    .lineLimit(1)
                Text(auth.selectedTeam?.name ?? "Developer team")
                    .font(OmniTypography.body(11))
                    .foregroundColor(OmniTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if auth.selectedTeam?.isFreeAccount == true {
                OmniPill(text: "Free", color: OmniTheme.warm)
            } else {
                OmniPill(text: "Developer", color: OmniTheme.accent)
            }
        }
    }

    @ViewBuilder
    private var teamSelector: some View {
        if auth.teams.count > 1 {
            Menu {
                ForEach(auth.teams) { team in
                    Button {
                        auth.selectTeam(team.teamID)
                    } label: {
                        if team.teamID == auth.selectedTeamID {
                            Label(team.name, systemImage: "checkmark")
                        } else {
                            Text(team.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(OmniTheme.tertiaryText)
                    Text(auth.selectedTeam?.name ?? "Choose a team")
                        .font(OmniTypography.label(12))
                        .foregroundColor(OmniTheme.secondaryText)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(OmniTheme.tertiaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(OmniTheme.hairline, lineWidth: 1)
                )
            }
        }
    }

    private var signOutButton: some View {
        Button(action: onRequestSignOut) {
            HStack(spacing: 7) {
                Image(systemName: "arrow.right.square")
                    .font(.system(size: 11, weight: .semibold))
                Text("Sign Out")
            }
            .font(OmniTypography.label(12))
            .foregroundColor(OmniTheme.secondaryText)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(Capsule().fill(Color.white.opacity(0.05)))
            .overlay(Capsule().strokeBorder(OmniTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var signInForm: some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 6) {
                SettingsFieldLabel(text: "APPLE ID")
                TextField("you@example.com", text: $auth.appleID)
                    .textFieldStyle(.plain)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .omniField()
                    .disabled(auth.isBusy)
            }

            VStack(alignment: .leading, spacing: 6) {
                SettingsFieldLabel(text: "PASSWORD")
                SecureField("Apple ID password", text: $auth.password)
                    .textFieldStyle(.plain)
                    .textContentType(.password)
                    .omniField()
                    .disabled(auth.isBusy)
                    .onSubmit(signIn)
            }

            DisclosureGroup(isExpanded: $isAdvancedExpanded) {
                VStack(alignment: .leading, spacing: 13) {
                    deviceUDIDField
                }
                .padding(.top, 12)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Advanced configuration")
                        .font(OmniTypography.label(12))
                    Spacer()
                }
                .foregroundColor(OmniTheme.secondaryText)
            }
            .accentColor(OmniTheme.secondaryText)

            Button(action: signIn) {
                HStack(spacing: 9) {
                    if auth.phase == .signingIn {
                        ProgressView()
                            .progressViewStyle(
                                CircularProgressViewStyle(tint: Color(red: 0.02, green: 0.08, blue: 0.06))
                            )
                    } else {
                        Image(systemName: "applelogo")
                            .font(.system(size: 14, weight: .medium))
                    }
                    Text(auth.phase == .signingIn ? "Signing In…" : "Sign In with Apple ID")
                }
            }
            .buttonStyle(OmniPrimaryButtonStyle())
            .disabled(!canSignIn)
            .opacity(canSignIn || auth.phase == .signingIn ? 1 : 0.52)

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.top, 2)
                Text("Your password is sent directly to Apple through SRP and discarded once the session starts. Only the certificate and profiles are saved.")
                    .font(OmniTypography.body(10))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundColor(OmniTheme.tertiaryText)
        }
    }

    private var deviceConfiguration: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                SettingsFieldLabel(text: "SIGNING CONFIGURATION")
                Spacer()
                Button {
                    auth.savePreferences()
                } label: {
                    Text("Save")
                        .font(OmniTypography.label(10))
                        .foregroundColor(OmniTheme.accent)
                }
                .buttonStyle(.plain)
                .disabled(auth.isSignedIn == false && auth.phase == .signingIn)
            }

            deviceUDIDField

            anisetteServerField
        }
    }

    private var anisetteServerField: some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 6) {
                SettingsFieldLabel(text: "ANISETTE SERVER")
                TextField(OmnistoreConstants.defaultAnisetteServer, text: $settings.anisetteServerURL)
                    .textFieldStyle(.plain)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .omniField()
            }

            Text("All client identity headers are taken verbatim from this server's Anisette response and forwarded to Apple.")
                .font(OmniTypography.body(10))
                .foregroundColor(OmniTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var deviceUDIDField: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsFieldLabel(text: "DEVICE UDID")
            TextField("00008030-001A2B3C4D5E6F70", text: $auth.deviceUDID)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .omniField()
            Text("Required to register this iPhone and build its provisioning profile. Find it in Finder under the device’s General tab.")
                .font(OmniTypography.body(10))
                .foregroundColor(OmniTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func signIn() {
        guard canSignIn else { return }
        Task {
            await auth.signIn()
        }
    }
}

// MARK: - Certificate

private struct CertificateSection: View {
    @EnvironmentObject private var auth: AuthManager
    let onRequestRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            OmniSectionHeader(
                title: "Signing certificate",
                subtitle: "Provisions apps for this device."
            )

            GlassCard(cornerRadius: 22, padding: 17) {
                VStack(alignment: .leading, spacing: 14) {
                    if let summary = auth.certificateSummary {
                        certificateDetails(summary)
                    } else {
                        missingCertificateState
                    }

                    if case .failed(let reason) = auth.certificatePreparation {
                        Text(reason)
                            .font(OmniTypography.body(11))
                            .foregroundColor(OmniTheme.danger.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    certificateActions
                }
            }
        }
    }

    private func certificateDetails(_ summary: CertificateSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(OmniTheme.accent.opacity(0.13))
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(OmniTheme.accent)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Identity ready")
                        .font(OmniTypography.title(14))
                        .foregroundColor(OmniTheme.primaryText)
                    Text(summary.teamName)
                        .font(OmniTypography.body(11))
                        .foregroundColor(OmniTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                OmniPill(text: "Ready", color: OmniTheme.accent)
            }

            VStack(spacing: 9) {
                SettingsInfoRow(label: "Issued", value: OmniFormat.abbreviatedDate(summary.issuedAt))
                SettingsInfoRow(label: "Profiles", value: "\(summary.profileCount) saved")
                SettingsInfoRow(
                    label: "Location",
                    value: "Documents/\(OmnistoreConstants.rootDirectoryName)/\(OmnistoreConstants.identityFileName)",
                    isMonospaced: true
                )
            }

            Text("Free developer certificates expire after 7 days. Preparing a new identity uses one of Apple’s limited certificate slots.")
                .font(OmniTypography.body(10))
                .foregroundColor(OmniTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var missingCertificateState: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(OmniTheme.warm.opacity(0.12))
                    Image(systemName: "key.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(OmniTheme.warm)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("No signing identity")
                        .font(OmniTypography.title(14))
                        .foregroundColor(OmniTheme.primaryText)
                    Text(auth.isSignedIn
                        ? "Prepare one before installing an IPA."
                        : "Sign in to request a development certificate.")
                        .font(OmniTypography.body(11))
                        .foregroundColor(OmniTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                OmniPill(
                    text: auth.isSignedIn ? "Needs setup" : "Signed out",
                    color: auth.isSignedIn ? OmniTheme.warm : OmniTheme.tertiaryText
                )
            }
        }
    }

    @ViewBuilder
    private var certificateActions: some View {
        if auth.isPreparingCertificate {
            HStack(spacing: 9) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: OmniTheme.accent))
                Text("Requesting a certificate from Apple…")
                    .font(OmniTypography.body(11))
                    .foregroundColor(OmniTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if auth.certificateSummary == nil {
            if auth.isSignedIn {
                Button {
                    Task {
                        await auth.prepareCertificate()
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Prepare Certificate")
                    }
                }
                .buttonStyle(OmniPrimaryButtonStyle())
            }
        } else {
            Button(action: onRequestRemove) {
                HStack(spacing: 7) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Remove Signing Identity")
                }
                .font(OmniTypography.label(12))
                .foregroundColor(OmniTheme.danger.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(OmniTheme.danger.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(OmniTheme.danger.opacity(0.18), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Installer

private struct InstallerSection: View {
    @EnvironmentObject private var installManager: InstallManager

    private var isMock: Bool {
        installManager.installerIsMock
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            OmniSectionHeader(
                title: "Installer",
                subtitle: isMock
                    ? "Simulation is active until minimuxer can reach a paired device."
                    : "Signed IPAs are handed directly to minimuxer."
            )

            GlassCard(cornerRadius: 22, padding: 17) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill((isMock ? OmniTheme.sky : OmniTheme.accent).opacity(0.12))
                            Image(systemName: isMock ? "testtube.2" : "bolt.horizontal.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(isMock ? OmniTheme.sky : OmniTheme.accent)
                        }
                        .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(isMock ? "Mock Installer" : "Minimuxer")
                                .font(OmniTypography.title(14))
                                .foregroundColor(OmniTheme.primaryText)
                            Text(isMock
                                ? "Add a pairing file to enable on-device installs."
                                : "Connected through the local VPN gateway.")
                                .font(OmniTypography.body(11))
                                .foregroundColor(OmniTheme.secondaryText)
                        }

                        Spacer(minLength: 6)

                        OmniPill(
                            text: isMock ? "Simulated" : "Ready",
                            color: isMock ? OmniTheme.sky : OmniTheme.accent
                        )
                    }

                    if isMock {
                        Rectangle()
                            .fill(OmniTheme.hairline)
                            .frame(height: 1)

                        VStack(alignment: .leading, spacing: 9) {
                            HStack {
                                SettingsFieldLabel(text: "INSTALL DELAY")
                                Spacer()
                                Text(OmniFormat.time(installManager.simulatedInstallDelay))
                                    .font(OmniTypography.mono(11))
                                    .foregroundColor(OmniTheme.secondaryText)
                            }

                            Slider(
                                value: $installManager.simulatedInstallDelay,
                                in: 0.2...5,
                                step: 0.1
                            )
                            .accentColor(OmniTheme.accent)
                            .disabled(installManager.isInstalling)

                            HStack {
                                Text("Snappy")
                                Spacer()
                                Text("Cinematic")
                            }
                            .font(OmniTypography.body(9))
                            .foregroundColor(OmniTheme.tertiaryText)
                        }

                        HStack(spacing: 11) {
                            Image(systemName: "ladybug.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(OmniTheme.warm)
                                .frame(width: 30, height: 30)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(OmniTheme.warm.opacity(0.10))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Force install failure")
                                    .font(OmniTypography.label(12))
                                    .foregroundColor(OmniTheme.primaryText)
                                Text("Exercise the error and retry states.")
                                    .font(OmniTypography.body(10))
                                    .foregroundColor(OmniTheme.tertiaryText)
                            }

                            Spacer()

                            Toggle("", isOn: $installManager.simulateInstallFailure)
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: OmniTheme.warm))
                                .disabled(installManager.isInstalling)
                        }
                    }

                    Text(isMock
                        ? "Place a pairing file at Documents/Omnistore/Pairing/pairing.mobiledevicepairing to let minimuxer reach this device. Until then every install stops after signing and runs in simulation."
                        : "Signed IPAs are copied to the device gateway and installed through MobileInstallation. Free developer certificates still expire after 7 days.")
                        .font(OmniTypography.body(10))
                        .foregroundColor(OmniTheme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Storage & Privacy

private struct StorageSection: View {
    private var credentialsPath: String {
        "Documents/\(OmnistoreConstants.rootDirectoryName)"
    }

    private var profilesPath: String {
        "Documents/\(OmnistoreConstants.rootDirectoryName)/\(OmnistoreConstants.profilesDirectoryName)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            OmniSectionHeader(
                title: "Storage & privacy",
                subtitle: "Zero Keychain. Local files only."
            )

            GlassCard(cornerRadius: 22, padding: 17) {
                VStack(alignment: .leading, spacing: 15) {
                    SecurityNoteRow(
                        symbol: "lock.shield.fill",
                        tint: OmniTheme.accent,
                        title: "No Keychain access",
                        detail: "Certificates and profiles are written directly to the app sandbox with atomic file operations. No Keychain APIs are used."
                    )

                    Rectangle()
                        .fill(OmniTheme.hairline)
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 8) {
                        SettingsFieldLabel(text: "ON-DEVICE LOCATIONS")

                        SettingsPathRow(icon: "folder.fill", title: "Credentials", path: credentialsPath)
                        SettingsPathRow(icon: "doc.text.fill", title: "Profiles", path: profilesPath)
                    }

                    Rectangle()
                        .fill(OmniTheme.hairline)
                        .frame(height: 1)

                    SecurityNoteRow(
                        symbol: "memorychip",
                        tint: OmniTheme.sky,
                        title: "Sessions stay in memory",
                        detail: "Your password is discarded after sign-in. Apple session tokens live only for the lifetime of the app process."
                    )
                }
            }
        }
    }
}

// MARK: - About

private struct AboutSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            OmniSectionHeader(title: "About")

            GlassCard(cornerRadius: 22, padding: 17) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 13) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(OmniTheme.heroGradient)
                            Image(systemName: "arrow.down.app.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white.opacity(0.92))
                        }
                        .frame(width: 54, height: 54)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(OmnistoreConstants.appName)
                                .font(OmniTypography.title(18))
                                .foregroundColor(OmniTheme.primaryText)
                            Text("A private sideloading workbench.")
                                .font(OmniTypography.body(11))
                                .foregroundColor(OmniTheme.secondaryText)
                        }

                        Spacer()

                        Text("v\(OmnistoreConstants.appVersion)")
                            .font(OmniTypography.mono(10))
                            .foregroundColor(OmniTheme.tertiaryText)
                    }

                    VStack(spacing: 9) {
                        SettingsInfoRow(label: "Signing engine", value: "GhostCode")
                        SettingsInfoRow(label: "Authentication", value: "GhostSign + Anisette")
                        SettingsInfoRow(label: "Installer", value: "Mock (bridge pending)")
                        SettingsInfoRow(label: "Minimum iOS", value: "15.0")
                    }

                    Text("OmniStore does not host, distribute, or condone piracy. Sign only apps you own or have permission to use.")
                        .font(OmniTypography.body(10))
                        .foregroundColor(OmniTheme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Small Settings Components

private struct SettingsFieldLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(1.2)
            .foregroundColor(OmniTheme.tertiaryText)
    }
}

private struct SettingsInfoRow: View {
    let label: String
    let value: String
    var isMonospaced = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(OmniTypography.body(11))
                .foregroundColor(OmniTheme.tertiaryText)
            Spacer(minLength: 12)
            Text(value)
                .font(isMonospaced ? OmniTypography.mono(9) : OmniTypography.label(11))
                .foregroundColor(OmniTheme.secondaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct SecurityNoteRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(tint.opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OmniTypography.label(12))
                    .foregroundColor(OmniTheme.primaryText)
                Text(detail)
                    .font(OmniTypography.body(10))
                    .foregroundColor(OmniTheme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SettingsPathRow: View {
    let icon: String
    let title: String
    let path: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(OmniTheme.tertiaryText)
                .frame(width: 16)

            Text(title)
                .font(OmniTypography.body(10))
                .foregroundColor(OmniTheme.tertiaryText)
                .frame(width: 70, alignment: .leading)

            Text(path)
                .font(OmniTypography.mono(9))
                .foregroundColor(OmniTheme.secondaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                )
        }
    }
}

private enum SettingsAlert: Identifiable {
    case signOut
    case removeCertificate

    var id: String {
        switch self {
        case .signOut: return "sign-out"
        case .removeCertificate: return "remove-certificate"
        }
    }
}
