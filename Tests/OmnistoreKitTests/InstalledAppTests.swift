import XCTest
@testable import OmnistoreKit

final class InstalledAppTests: XCTestCase {
    func testLifecycleStatusTransitions() {
        let active = makeApp(expiresIn: 10 * 86_400)
        XCTAssertEqual(active.status, .active)
        XCTAssertFalse(active.isExpired)
        XCTAssertFalse(active.needsRefresh)

        let expiring = makeApp(expiresIn: 86_400)
        XCTAssertEqual(expiring.status, .expiringSoon)
        XCTAssertTrue(expiring.needsRefresh)

        let expired = makeApp(expiresIn: -3_600)
        XCTAssertEqual(expired.status, .expired)
        XCTAssertTrue(expired.isExpired)
        XCTAssertEqual(expired.daysRemaining, 0)
    }

    func testDaysRemainingRoundsUp() {
        let app = makeApp(expiresIn: 1.2 * 86_400)
        XCTAssertEqual(app.daysRemaining, 2)
    }

    func testDemoDetection() {
        let demo = InstalledApp(
            bundleIdentifier: "com.omnistore.demo.solstice",
            name: "Solstice",
            version: "1.0"
        )
        XCTAssertTrue(demo.isDemo)

        let production = InstalledApp(
            bundleIdentifier: "com.example.app",
            name: "Example",
            version: "1.0"
        )
        XCTAssertFalse(production.isDemo)
    }

    func testCodableRoundTrip() throws {
        let app = InstalledApp(
            bundleIdentifier: "com.example.roundtrip",
            name: "Round Trip",
            version: "2.4.0",
            developerName: "Example Studio",
            installedDate: Date(timeIntervalSince1970: 1_700_000_000),
            expirationDate: Date(timeIntervalSince1970: 1_700_600_000),
            iconSystemName: "app.fill",
            certificateId: "CERT123",
            originalIPAFileName: "RoundTrip.ipa"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(app)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(InstalledApp.self, from: data)

        XCTAssertEqual(decoded.bundleIdentifier, app.bundleIdentifier)
        XCTAssertEqual(decoded.name, app.name)
        XCTAssertEqual(decoded.version, app.version)
        XCTAssertEqual(decoded.developerName, app.developerName)
        XCTAssertEqual(decoded.certificateId, app.certificateId)
        XCTAssertEqual(decoded.isDemo, app.isDemo)
    }

    func testSamplesCoverEveryLifecycleState() {
        let statuses = Set(InstalledApp.sampleApps.map(\.status))
        XCTAssertTrue(statuses.contains(.active))
        XCTAssertTrue(statuses.contains(.expiringSoon))
        XCTAssertTrue(statuses.contains(.expired))
        XCTAssertEqual(InstalledApp.sampleApps.count, 4)
    }

    private func makeApp(expiresIn interval: TimeInterval) -> InstalledApp {
        InstalledApp(
            bundleIdentifier: "com.example.lifecycle",
            name: "Lifecycle",
            version: "1.0",
            expirationDate: Date().addingTimeInterval(interval)
        )
    }
}
