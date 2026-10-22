//
//  BrowseView.swift
//  OmniStore
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import OmnistoreKit

struct BrowseView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var installManager: InstallManager

    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var isImporterPresented = false
    @State private var importError: String?

    private let categories = ["All", "Productivity", "Creative", "Utilities", "Play"]

    private var filteredEntries: [BrowseEntry] {
        BrowseEntry.catalog.filter { entry in
            let matchesCategory = selectedCategory == "All" || entry.category == selectedCategory
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty
                || entry.name.localizedCaseInsensitiveContains(query)
                || entry.subtitle.localizedCaseInsensitiveContains(query)
                || entry.category.localizedCaseInsensitiveContains(query)
            return matchesCategory && matchesSearch
        }
    }

    var body: some View {
        ZStack {
            AmbientBackground(tint: OmniTheme.sky)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    importHero
                    searchField
                    categoryChips
                    discoverSection
                    howItWorks
                    disclaimer
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 116)
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [UTType.data]
        ) { result in
            switch result {
            case .success(let url):
                installManager.install(ipaURL: url)
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .alert(
            "Couldn’t Import IPA",
            isPresented: Binding(
                get: { importError != nil },
                set: { isPresented in
                    if !isPresented {
                        importError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                importError = nil
            }
        } message: {
            Text(importError ?? "The selected file could not be read.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Browse")
                .font(OmniTypography.display(34))
                .foregroundColor(OmniTheme.primaryText)
            Text("Find something new to make your own.")
                .font(OmniTypography.body(13))
                .foregroundColor(OmniTheme.secondaryText)
        }
    }

    // MARK: - Import Hero

    private var importHero: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(OmniTheme.heroGradient)

            Circle()
                .fill(OmniTheme.sky.opacity(0.26))
                .frame(width: 180, height: 180)
                .blur(radius: 46)
                .offset(x: 48, y: -68)

            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(OmniTheme.accent)
                            .frame(width: 5, height: 5)
                        Text("LOCAL SIDELOAD")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(1.2)
                            .foregroundColor(.white.opacity(0.82))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))

                    Spacer()

                    Image(systemName: "arrow.down.app.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(.white.opacity(0.24))
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Bring your own IPA")
                        .font(OmniTypography.display(26))
                        .foregroundColor(.white.opacity(0.97))
                    Text("OmniStore unpacks the archive, signs every Mach-O slice with GhostCode, rewraps it, and hands it to the device gateway.")
                        .font(OmniTypography.body(12))
                        .foregroundColor(.white.opacity(0.64))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    isImporterPresented = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Choose IPA File")
                    }
                }
                .buttonStyle(OmniPrimaryButtonStyle(tint: OmniTheme.accent))
                .disabled(installManager.isInstalling)
                .opacity(installManager.isInstalling ? 0.55 : 1)

                HStack(spacing: 6) {
                    Image(systemName: auth.isSignedIn ? "checkmark.seal.fill" : "testtube.2")
                        .font(.system(size: 10, weight: .semibold))
                    Text(signingModeDescription)
                        .font(OmniTypography.body(10))
                        .lineLimit(2)
                }
                .foregroundColor(.white.opacity(0.52))
            }
            .padding(20)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color.black.opacity(0.30), radius: 22, x: 0, y: 12)
    }

    private var signingModeDescription: String {
        if auth.isSignedIn {
            let team = auth.selectedTeam?.name ?? "your Apple ID team"
            return "Apple Development signed with \(team)."
        }
        return "Demo mode: installs use an ad-hoc signature until you sign in."
    }

    // MARK: - Search & Filters

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(OmniTheme.tertiaryText)

            TextField("Search the preview catalog", text: $searchText)
                .textFieldStyle(.plain)
                .font(OmniTypography.body(14))
                .foregroundColor(OmniTheme.primaryText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accentColor(OmniTheme.accent)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(OmniTheme.tertiaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(OmniTheme.hairline, lineWidth: 1)
        )
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    let isSelected = selectedCategory == category
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    } label: {
                        Text(category)
                            .font(OmniTypography.label(12))
                            .foregroundColor(
                                isSelected
                                    ? Color(red: 0.02, green: 0.08, blue: 0.06)
                                    : OmniTheme.secondaryText
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(isSelected ? OmniTheme.accent : Color.white.opacity(0.055))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        isSelected
                                            ? Color.clear
                                            : OmniTheme.hairline,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Catalog

    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OmniSectionHeader(
                title: "Curated picks",
                subtitle: "A preview of the shelves to come.",
                trailingText: "Soon"
            )

            if filteredEntries.isEmpty {
                GlassCard(cornerRadius: 20, padding: 22) {
                    VStack(spacing: 9) {
                        EmptyIconView(symbol: "magnifyingglass", size: 40, tint: OmniTheme.secondaryText)
                        Text("Nothing on this shelf yet")
                            .font(OmniTypography.title(14))
                            .foregroundColor(OmniTheme.primaryText)
                        Text("Try another category or clear your search.")
                            .font(OmniTypography.body(11))
                            .foregroundColor(OmniTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                    ],
                    spacing: 12
                ) {
                    ForEach(filteredEntries) { entry in
                        BrowseCard(entry: entry)
                    }
                }
            }
        }
    }

    // MARK: - Guide

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 12) {
            OmniSectionHeader(
                title: "How sideloading works",
                subtitle: "Everything happens on this device."
            )

            GlassCard(cornerRadius: 22, padding: 17) {
                VStack(spacing: 16) {
                    GuideStep(
                        number: "01",
                        symbol: "doc.badge.plus",
                        title: "Pick an IPA",
                        detail: "Choose an archive from Files. OmniStore validates its Payload and reads the bundle metadata.",
                        showsDivider: true
                    )
                    GuideStep(
                        number: "02",
                        symbol: "checkmark.shield.fill",
                        title: "Sign it locally",
                        detail: "GhostCode signs the app bundle. GhostSign requests a development certificate and profile from your Apple ID.",
                        showsDivider: true
                    )
                    GuideStep(
                        number: "03",
                        symbol: "arrow.down.app.fill",
                        title: "Hand it to the installer",
                        detail: "The signed IPA is passed to the installer gateway. Minimuxer will replace the mock once the bridge lands.",
                        showsDivider: false
                    )
                }
            }
        }
    }

    private var disclaimer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 9, weight: .semibold))
                Text("Catalog cards are placeholders. OmniStore does not host or distribute apps.")
                    .font(OmniTypography.body(10))
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(OmniTheme.tertiaryText)

            HStack(spacing: 6) {
                Image(systemName: "testtube.2")
                    .font(.system(size: 9, weight: .semibold))
                Text("Mock installer active · Minimuxer bridge pending")
                    .font(OmniTypography.body(10))
            }
            .foregroundColor(OmniTheme.tertiaryText.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}

// MARK: - Supporting Views

private struct BrowseCard: View {
    let entry: BrowseEntry

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.048))

            Circle()
                .fill(entry.tint.opacity(0.22))
                .frame(width: 110, height: 110)
                .blur(radius: 34)
                .offset(x: 38, y: -38)

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    EmptyIconView(symbol: entry.symbol, size: 38, tint: entry.tint)
                    Spacer()
                    Text("SOON")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(1.0)
                        .foregroundColor(OmniTheme.tertiaryText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                }

                Spacer(minLength: 4)

                Text(entry.name)
                    .font(OmniTypography.title(15))
                    .foregroundColor(OmniTheme.primaryText)
                    .lineLimit(1)

                Text(entry.subtitle)
                    .font(OmniTypography.body(10))
                    .foregroundColor(OmniTheme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(entry.category.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(1.0)
                    .foregroundColor(entry.tint.opacity(0.85))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(14)
        }
        .frame(height: 162)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [entry.tint.opacity(0.20), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct GuideStep: View {
    let number: String
    let symbol: String
    let title: String
    let detail: String
    let showsDivider: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                EmptyIconView(symbol: symbol, size: 36, tint: OmniTheme.accent)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(title)
                            .font(OmniTypography.title(13))
                            .foregroundColor(OmniTheme.primaryText)
                        Text(number)
                            .font(OmniTypography.mono(9))
                            .foregroundColor(OmniTheme.tertiaryText)
                    }
                    Text(detail)
                        .font(OmniTypography.body(11))
                        .foregroundColor(OmniTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if showsDivider {
                Rectangle()
                    .fill(OmniTheme.hairline)
                    .frame(height: 1)
                    .padding(.leading, 48)
            }
        }
    }
}

private struct BrowseEntry: Identifiable {
    let name: String
    let subtitle: String
    let category: String
    let symbol: String
    let tint: Color

    var id: String { name }

    static let catalog: [BrowseEntry] = [
        BrowseEntry(
            name: "Monument",
            subtitle: "A quiet home for the places that matter.",
            category: "Productivity",
            symbol: "mappin.and.ellipse",
            tint: OmniTheme.accent
        ),
        BrowseEntry(
            name: "Prism",
            subtitle: "Photo grading tools with tactile controls.",
            category: "Creative",
            symbol: "camera.filters",
            tint: OmniTheme.sky
        ),
        BrowseEntry(
            name: "Terminal",
            subtitle: "A pocket SSH workspace for quick fixes.",
            category: "Utilities",
            symbol: "chevron.left.forwardslash.chevron.right",
            tint: OmniTheme.lavender
        ),
        BrowseEntry(
            name: "Nightwave",
            subtitle: "Ambient soundscapes for deep focus.",
            category: "Creative",
            symbol: "waveform",
            tint: OmniTheme.warm
        ),
        BrowseEntry(
            name: "Grove",
            subtitle: "A calm habit tracker that grows with you.",
            category: "Productivity",
            symbol: "leaf.fill",
            tint: Color(red: 0.542, green: 0.847, blue: 0.437)
        ),
        BrowseEntry(
            name: "Driftline",
            subtitle: "An arcade racer built for one more run.",
            category: "Play",
            symbol: "gamecontroller.fill",
            tint: OmniTheme.danger
        ),
    ]
}
