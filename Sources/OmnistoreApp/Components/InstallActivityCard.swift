//
//  InstallActivityCard.swift
//  OmniStore
//

import Foundation
import SwiftUI
import OmnistoreKit

struct InstallActivityCard: View {
    let progress: PipelineProgress
    let appName: String?
    let isMock: Bool
    let onCancel: () -> Void
    let onDismiss: () -> Void

    private var stageColor: Color {
        switch progress.stage {
        case .failed: return OmniTheme.danger
        case .completed: return OmniTheme.accent
        case .provisioning, .signing: return OmniTheme.lavender
        case .packaging, .installing: return OmniTheme.sky
        default: return OmniTheme.warm
        }
    }

    private var stageSymbol: String {
        switch progress.stage {
        case .idle: return "sparkles"
        case .preparing: return "shippingbox.fill"
        case .provisioning: return "key.fill"
        case .signing: return "checkmark.shield.fill"
        case .packaging: return "archivebox.fill"
        case .installing: return "arrow.down.app.fill"
        case .completed: return "checkmark.seal.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var title: String {
        if let appName, !appName.isEmpty {
            return appName
        }
        return OmniStoreCopy.appName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(stageColor.opacity(0.14))
                    Image(systemName: stageSymbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(stageColor)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(OmniTypography.title(15))
                            .foregroundColor(OmniTheme.primaryText)
                            .lineLimit(1)
                        if isMock {
                            OmniPill(text: "Mock", color: OmniTheme.sky)
                        }
                    }
                    Text(progress.stage.title)
                        .font(OmniTypography.label(11))
                        .foregroundColor(stageColor)
                }

                Spacer(minLength: 8)

                if progress.stage.isTerminal {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(OmniTheme.secondaryText)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss install status")
                }
            }

            Text(progress.errorDescription ?? progress.message)
                .font(OmniTypography.body(12))
                .foregroundColor(
                    progress.stage == .failed
                        ? OmniTheme.primaryText.opacity(0.82)
                        : OmniTheme.secondaryText
                )
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)

            if progress.stage.isActive {
                VStack(spacing: 7) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [stageColor, stageColor.opacity(0.65)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: max(6, proxy.size.width * min(max(progress.fraction, 0), 1))
                                )
                        }
                    }
                    .frame(height: 5)

                    HStack {
                        Text(progress.stage == .installing ? "Installing to this device" : "Working…")
                            .font(OmniTypography.body(10))
                            .foregroundColor(OmniTheme.tertiaryText)
                        Spacer()
                        Text(OmniFormat.percent(progress.fraction))
                            .font(OmniTypography.mono(10))
                            .foregroundColor(OmniTheme.secondaryText)
                    }
                }

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(OmniTypography.label(12))
                        .foregroundColor(OmniTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color.white.opacity(0.055))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(OmniTheme.hairline, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            } else if progress.stage == .completed {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Added to your library")
                        .font(OmniTypography.label(12))
                }
                .foregroundColor(OmniTheme.accent)
            }
        }
        .padding(15)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.055, green: 0.068, blue: 0.088).opacity(0.92))
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.65)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [stageColor.opacity(0.34), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.42), radius: 24, x: 0, y: 12)
        .animation(.easeInOut(duration: 0.3), value: progress)
    }
}

enum OmniStoreCopy {
    static let appName = "OmniStore"
}
