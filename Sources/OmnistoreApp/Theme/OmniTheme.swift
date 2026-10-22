//
//  OmniTheme.swift
//  OmniStore
//
//  A small design system for the dark, glass-heavy interface.
//

import Foundation
import SwiftUI

enum OmniTheme {
    static let canvas = Color(red: 0.030, green: 0.036, blue: 0.052)
    static let canvasDeep = Color(red: 0.016, green: 0.020, blue: 0.032)
    static let accent = Color(red: 0.372, green: 0.827, blue: 0.690)
    static let accentDeep = Color(red: 0.176, green: 0.588, blue: 0.518)
    static let sky = Color(red: 0.463, green: 0.702, blue: 0.973)
    static let lavender = Color(red: 0.647, green: 0.596, blue: 0.965)
    static let warm = Color(red: 0.973, green: 0.686, blue: 0.420)
    static let danger = Color(red: 0.965, green: 0.412, blue: 0.435)

    static let primaryText = Color.white.opacity(0.96)
    static let secondaryText = Color.white.opacity(0.58)
    static let tertiaryText = Color.white.opacity(0.38)

    static let cardFill = Color.white.opacity(0.052)
    static let cardFillStrong = Color.white.opacity(0.082)
    static let hairline = Color.white.opacity(0.10)
    static let hairlineStrong = Color.white.opacity(0.17)

    static let cardRadius: CGFloat = 24
    static let innerRadius: CGFloat = 16

    static let accentGradient = LinearGradient(
        colors: [accent, Color(red: 0.361, green: 0.722, blue: 0.867)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.129, green: 0.290, blue: 0.267),
            Color(red: 0.126, green: 0.196, blue: 0.318),
            Color(red: 0.161, green: 0.133, blue: 0.286),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func iconGradient(for index: Int) -> LinearGradient {
        let palettes: [[Color]] = [
            [Color(red: 0.376, green: 0.831, blue: 0.686), Color(red: 0.184, green: 0.541, blue: 0.522)],
            [Color(red: 0.478, green: 0.647, blue: 0.976), Color(red: 0.333, green: 0.369, blue: 0.784)],
            [Color(red: 0.965, green: 0.686, blue: 0.443), Color(red: 0.784, green: 0.365, blue: 0.361)],
            [Color(red: 0.722, green: 0.608, blue: 0.980), Color(red: 0.396, green: 0.373, blue: 0.776)],
            [Color(red: 0.396, green: 0.784, blue: 0.827), Color(red: 0.235, green: 0.451, blue: 0.667)],
        ]
        guard !palettes.isEmpty else {
            return accentGradient
        }
        let palette = palettes[abs(index) % palettes.count]
        return LinearGradient(
            colors: [palette[0], palette[1]],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func statusColor(for status: AppLifecycleStatus) -> Color {
        switch status {
        case .active: return accent
        case .expiringSoon: return warm
        case .expired: return danger
        }
    }
}

enum OmniTypography {
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func body(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    static func label(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

enum OmniFormat {
    static func abbreviatedDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    static func time(_ seconds: Double) -> String {
        String(format: "%.1f s", seconds)
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((min(max(fraction, 0), 1) * 100).rounded()))%"
    }
}

// MARK: - Surfaces

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat
    var padding: CGFloat
    var isHighlighted: Bool
    let content: Content

    init(
        cornerRadius: CGFloat = OmniTheme.cardRadius,
        padding: CGFloat = 18,
        isHighlighted: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.isHighlighted = isHighlighted
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(OmniTheme.cardFill)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.55)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHighlighted ? 0.25 : 0.16),
                                Color.white.opacity(0.035),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct AmbientBackground: View {
    var tint: Color = OmniTheme.accent

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                LinearGradient(
                    colors: [OmniTheme.canvas, OmniTheme.canvasDeep],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [tint.opacity(0.24), .clear],
                    center: UnitPoint(x: 0.08, y: 0.02),
                    startRadius: 8,
                    endRadius: width * 0.95
                )

                RadialGradient(
                    colors: [OmniTheme.sky.opacity(0.15), .clear],
                    center: UnitPoint(x: 0.92, y: 0.18),
                    startRadius: 10,
                    endRadius: width * 0.82
                )

                RadialGradient(
                    colors: [OmniTheme.lavender.opacity(0.10), .clear],
                    center: UnitPoint(x: 0.55, y: 0.94),
                    startRadius: 12,
                    endRadius: height * 0.55
                )

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.28)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
            .blur(radius: 18)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Small Building Blocks

struct OmniSectionHeader: View {
    let title: String
    var subtitle: String?
    var trailingText: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OmniTypography.title(19))
                    .foregroundColor(OmniTheme.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(OmniTypography.body(13))
                        .foregroundColor(OmniTheme.secondaryText)
                }
            }
            Spacer(minLength: 8)
            if let trailingText {
                Text(trailingText.uppercased())
                    .font(OmniTypography.label(10))
                    .tracking(1.1)
                    .foregroundColor(OmniTheme.tertiaryText)
            }
        }
    }
}

struct OmniPill: View {
    let text: String
    var color: Color = OmniTheme.accent

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(0.9)
            .foregroundColor(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.13))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.22), lineWidth: 1))
    }
}

struct StatusPill: View {
    let app: InstalledApp

    var body: some View {
        let status = app.status
        let color = OmniTheme.statusColor(for: status)

        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(pillText(for: status))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundColor(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.11))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.20), lineWidth: 1))
    }

    private func pillText(for status: AppLifecycleStatus) -> String {
        switch status {
        case .active: return "Active"
        case .expiringSoon: return "Expires soon"
        case .expired: return "Expired"
        }
    }
}

struct OmniIconButtonStyle: ButtonStyle {
    var size: CGFloat = 44
    var tint: Color = OmniTheme.primaryText

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.14 : 0.075))
            )
            .overlay(Circle().strokeBorder(OmniTheme.hairline, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct OmniPrimaryButtonStyle: ButtonStyle {
    var tint: Color = OmniTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(OmniTypography.label(15))
            .foregroundColor(Color(red: 0.02, green: 0.08, blue: 0.06))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.80 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct OmniSecondaryButtonStyle: ButtonStyle {
    var tint: Color = OmniTheme.primaryText

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(OmniTypography.label(14))
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.11 : 0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(OmniTheme.hairline, lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct OmniFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(OmniTypography.body(15))
            .foregroundColor(OmniTheme.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(OmniTheme.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func omniField() -> some View {
        modifier(OmniFieldModifier())
    }
}

struct OmniErrorBanner: View {
    let message: String
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(OmniTheme.warm)
                .padding(.top, 1)
            Text(message)
                .font(OmniTypography.body(12))
                .foregroundColor(OmniTheme.primaryText.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(OmniTheme.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(OmniTheme.warm.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(OmniTheme.warm.opacity(0.22), lineWidth: 1)
        )
    }
}
