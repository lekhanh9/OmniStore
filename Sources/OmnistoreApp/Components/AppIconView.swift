//
//  AppIconView.swift
//  OmniStore
//

import Foundation
import SwiftUI
import UIKit
import OmnistoreKit

struct AppIconView: View {
    let app: InstalledApp
    var size: CGFloat = 58
    var paletteIndex: Int = 0

    var body: some View {
        ZStack {
            if let iconURL = app.iconURL,
               let image = UIImage(contentsOfFile: iconURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                OmniTheme.iconGradient(for: paletteIndex)
                Image(systemName: app.iconSystemName ?? "app.fill")
                    .font(.system(size: size * 0.38, weight: .medium))
                    .foregroundColor(.white.opacity(0.94))
                    .shadow(color: Color.black.opacity(0.24), radius: 4, x: 0, y: 2)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: size * 0.14, x: 0, y: size * 0.08)
        .accessibilityHidden(true)
    }
}

struct EmptyIconView: View {
    var symbol: String = "app.fill"
    var size: CGFloat = 44
    var tint: Color = OmniTheme.accent

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(tint.opacity(0.12))
            Image(systemName: symbol)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundColor(tint)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        )
    }
}
