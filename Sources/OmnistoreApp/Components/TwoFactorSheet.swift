//
//  TwoFactorSheet.swift
//  OmniStore
//

import Foundation
import SwiftUI
import OmnistoreKit

struct TwoFactorSheet: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isCodeFocused: Bool

    private var codeBinding: Binding<String> {
        Binding(
            get: { auth.twoFactorCode },
            set: { newValue in
                let digits = newValue.filter { $0.isNumber }
                auth.twoFactorCode = String(digits.prefix(6))
            }
        )
    }

    private var isVerifying: Bool {
        auth.phase == .verifyingTwoFactor
    }

    var body: some View {
        ZStack {
            AmbientBackground(tint: OmniTheme.lavender)

            ScrollView {
                VStack(spacing: 24) {
                    sheetHeader
                    verificationCard
                    trustNote
                    Button(action: cancel) {
                        Text("Use a different Apple ID")
                            .font(OmniTypography.label(13))
                            .foregroundColor(OmniTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .disabled(isVerifying)
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            isCodeFocused = true
        }
    }

    private var sheetHeader: some View {
        VStack(spacing: 14) {
            HStack {
                EmptyIconView(symbol: "lock.shield.fill", size: 46, tint: OmniTheme.lavender)
                Spacer()
                Button(action: cancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(OmniTheme.secondaryText)
                }
                .buttonStyle(OmniIconButtonStyle(size: 36))
                .disabled(isVerifying)
                .opacity(isVerifying ? 0.4 : 1)
                .accessibilityLabel("Cancel verification")
            }

            VStack(spacing: 7) {
                Text("Two-factor verification")
                    .font(OmniTypography.display(26))
                    .foregroundColor(OmniTheme.primaryText)
                    .multilineTextAlignment(.center)
                Text("Apple sent a code to the trusted devices signed in with your Apple ID.")
                    .font(OmniTypography.body(14))
                    .foregroundColor(OmniTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var verificationCard: some View {
        GlassCard(cornerRadius: 26, padding: 20, isHighlighted: true) {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("VERIFICATION CODE")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.3)
                        .foregroundColor(OmniTheme.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ZStack {
                        if auth.twoFactorCode.isEmpty {
                            Text("000000")
                                .font(.system(size: 30, weight: .semibold, design: .monospaced))
                                .foregroundColor(OmniTheme.tertiaryText.opacity(0.55))
                        }

                        TextField("", text: codeBinding)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 30, weight: .semibold, design: .monospaced))
                            .foregroundColor(OmniTheme.primaryText)
                            .accentColor(OmniTheme.lavender)
                            .focused($isCodeFocused)
                            .disabled(isVerifying)
                            .accessibilityLabel("Six digit verification code")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.055))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isCodeFocused
                                    ? OmniTheme.lavender.opacity(0.45)
                                    : OmniTheme.hairline,
                                lineWidth: 1
                            )
                    )
                }

                if let error = auth.lastError, !error.isEmpty {
                    OmniErrorBanner(message: error) {
                        auth.clearError()
                    }
                }

                Button(action: submit) {
                    HStack(spacing: 9) {
                        if isVerifying {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.02, green: 0.08, blue: 0.06)))
                        }
                        Text(isVerifying ? "Verifying…" : "Verify Code")
                    }
                }
                .buttonStyle(OmniPrimaryButtonStyle(tint: OmniTheme.lavender))
                .disabled(auth.twoFactorCode.count < 6 || isVerifying)
                .opacity(auth.twoFactorCode.count < 6 || isVerifying ? 0.55 : 1)
            }
        }
    }

    private var trustNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(OmniTheme.sky)
            Text("The code is sent directly to Apple. OmniStore only forwards it through the Anisette server; it is never saved on this device.")
                .font(OmniTypography.body(12))
                .foregroundColor(OmniTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(OmniTheme.sky.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(OmniTheme.sky.opacity(0.14), lineWidth: 1)
        )
    }

    private func submit() {
        guard auth.twoFactorCode.count >= 6, !isVerifying else { return }
        Task {
            await auth.submitTwoFactorCode()
        }
    }

    private func cancel() {
        auth.cancelTwoFactor()
        dismiss()
    }
}
