import XCTest
@testable import OmnistoreKit

final class IdentityStoreTests: XCTestCase {
    private var root: URL?

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OmnistoreIdentityTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let root {
            do {
                if FileManager.default.fileExists(atPath: root.path) {
                    try FileManager.default.removeItem(at: root)
                }
            } catch {
                XCTFail("Could not clean up test directory: \(error)")
            }
            self.root = nil
        }
    }

    func testSaveLoadAndRemoveIdentity() async throws {
        let directory = try XCTUnwrap(root)
        let store = IdentityStore(baseDirectory: directory)
        let issuedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let metadata = StoredIdentityMetadata(
            appleID: "developer@example.com",
            teamID: "TEAM123456",
            teamName: "Example Team",
            certificateID: "CERT123456",
            certificateSerialNumber: "SERIAL",
            issuedAt: issuedAt
        )

        try await store.saveIdentity(
            p12Data: Data([0x30, 0x82, 0x01]),
            certificateDER: Data([0x30, 0x82, 0x02]),
            metadata: metadata
        )

        let paths = await store.identityPaths()
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.p12))
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.certificate))

        let loaded = try await store.loadIdentity()
        let identity = try XCTUnwrap(loaded)
        XCTAssertEqual(identity.metadata.appleID, metadata.appleID)
        XCTAssertEqual(identity.metadata.teamID, metadata.teamID)
        XCTAssertEqual(identity.metadata.teamName, metadata.teamName)
        XCTAssertEqual(identity.metadata.certificateID, metadata.certificateID)
        XCTAssertEqual(identity.metadata.issuedAt.timeIntervalSince1970, issuedAt.timeIntervalSince1970)
        XCTAssertEqual(identity.p12Data, Data([0x30, 0x82, 0x01]))
        XCTAssertEqual(identity.certificateDER, Data([0x30, 0x82, 0x02]))

        try await store.removeCredentials()
        let removed = try await store.loadIdentity()
        XCTAssertNil(removed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.p12))
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.certificate))
    }

    func testMissingIdentityReturnsNil() async throws {
        let directory = try XCTUnwrap(root)
        let store = IdentityStore(baseDirectory: directory)
        let identity = try await store.loadIdentity()
        XCTAssertNil(identity)
    }

    func testProvisioningProfilesStayInsideProfilesDirectory() async throws {
        let directory = try XCTUnwrap(root)
        let store = IdentityStore(baseDirectory: directory)

        let url = try await store.saveProvisioningProfile(
            Data([1, 2, 3, 4]),
            bundleIdentifier: "../../com.example/unsafe app"
        )

        let profilesDirectory = await store.profilesDirectory
        XCTAssertEqual(
            url.deletingLastPathComponent().standardizedFileURL.path,
            profilesDirectory.standardizedFileURL.path
        )
        XCTAssertEqual(url.pathExtension, "mobileprovision")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let count = try await store.profileCount()
        XCTAssertEqual(count, 1)

        let found = try await store.provisioningProfileURL(for: "../../com.example/unsafe app")
        XCTAssertEqual(found?.standardizedFileURL.path, url.standardizedFileURL.path)
    }

    func testRemoveCredentialsDeletesProvisioningProfiles() async throws {
        let directory = try XCTUnwrap(root)
        let store = IdentityStore(baseDirectory: directory)

        let profileURL = try await store.saveProvisioningProfile(
            Data([9, 9, 9]),
            bundleIdentifier: "com.example.profile"
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: profileURL.path))

        try await store.saveIdentity(
            p12Data: Data([1]),
            certificateDER: Data([2]),
            metadata: StoredIdentityMetadata(
                appleID: "developer@example.com",
                teamID: "TEAM123456",
                teamName: "Example Team",
                certificateID: "CERT123456",
                certificateSerialNumber: nil,
                issuedAt: Date()
            )
        )

        try await store.removeCredentials()

        XCTAssertFalse(FileManager.default.fileExists(atPath: profileURL.path))
        let remaining = try await store.profileCount()
        XCTAssertEqual(remaining, 0)
    }
}
