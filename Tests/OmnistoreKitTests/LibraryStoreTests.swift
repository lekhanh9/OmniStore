import XCTest
@testable import OmnistoreKit

final class LibraryStoreTests: XCTestCase {
    private var root: URL?

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OmnistoreLibraryTests-\(UUID().uuidString)", isDirectory: true)
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

    func testUpsertAndRemoveApps() async throws {
        let directory = try XCTUnwrap(root)
        let store = LibraryStore(baseDirectory: directory)

        let initial = try await store.load()
        XCTAssertTrue(initial.isEmpty)

        let first = makeApp(bundleIdentifier: "com.example.one", name: "One")
        let second = makeApp(bundleIdentifier: "com.example.two", name: "Two")

        var apps = try await store.upsert(first)
        XCTAssertEqual(apps.count, 1)

        apps = try await store.upsert(second)
        XCTAssertEqual(apps.count, 2)

        let updatedFirst = makeApp(bundleIdentifier: "com.example.one", name: "One Updated")
        apps = try await store.upsert(updatedFirst)
        XCTAssertEqual(apps.count, 2)
        XCTAssertEqual(apps.first(where: { $0.bundleIdentifier == "com.example.one" })?.name, "One Updated")

        let reloaded = try await store.load()
        XCTAssertEqual(reloaded.count, 2)

        apps = try await store.remove(bundleIdentifier: "com.example.two")
        XCTAssertEqual(apps.count, 1)
        XCTAssertEqual(apps.first?.bundleIdentifier, "com.example.one")
    }

    func testIconLifecycle() async throws {
        let directory = try XCTUnwrap(root)
        let store = LibraryStore(baseDirectory: directory)

        let iconURL = try await store.saveIcon(
            Data([0x89, 0x50, 0x4E, 0x47]),
            bundleIdentifier: "com.example.icon"
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: iconURL.path))
        XCTAssertEqual(iconURL.pathExtension, "png")

        try await store.removeIcon(at: iconURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: iconURL.path))
    }

    func testRemoveIconIgnoresFilesOutsideIconsDirectory() async throws {
        let directory = try XCTUnwrap(root)
        let store = LibraryStore(baseDirectory: directory)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let externalURL = directory.appendingPathComponent("do-not-delete.txt")
        try Data([1, 2, 3]).write(to: externalURL)

        try await store.removeIcon(at: externalURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: externalURL.path))
    }

    func testIconFileNamesAreSanitized() async throws {
        let directory = try XCTUnwrap(root)
        let store = LibraryStore(baseDirectory: directory)

        let iconURL = try await store.saveIcon(
            Data([1, 2, 3]),
            bundleIdentifier: "com.example/../unsafe icon"
        )

        let iconsDirectory = await store.iconsDirectory
        XCTAssertEqual(
            iconURL.deletingLastPathComponent().standardizedFileURL.path,
            iconsDirectory.standardizedFileURL.path
        )
        XCTAssertFalse(iconURL.lastPathComponent.contains("/"))
        XCTAssertFalse(iconURL.lastPathComponent.contains(" "))
    }

    private func makeApp(bundleIdentifier: String, name: String) -> InstalledApp {
        InstalledApp(
            bundleIdentifier: bundleIdentifier,
            name: name,
            version: "1.0",
            installedDate: Date(timeIntervalSince1970: 1_700_000_000),
            expirationDate: Date(timeIntervalSince1970: 1_700_600_000)
        )
    }
}
