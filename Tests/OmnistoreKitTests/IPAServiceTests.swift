import XCTest
import ZIPFoundation
@testable import OmnistoreKit

final class IPAServiceTests: XCTestCase {
    private var root: URL?

    override func setUpWithError() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OmnistoreIPATests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        root = directory
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

    func testPrepareReadsMetadataAndPackageRecreatesPayload() async throws {
        let directory = try XCTUnwrap(root)
        let ipaURL = try makeFixtureIPA(in: directory)
        let service = IPAService()
        let workspaceRoot = directory.appendingPathComponent("Workspaces", isDirectory: true)

        let prepared = try await service.prepare(ipaURL: ipaURL, workspaceRoot: workspaceRoot)
        XCTAssertEqual(prepared.metadata.bundleIdentifier, "com.example.demo")
        XCTAssertEqual(prepared.metadata.name, "Demo App")
        XCTAssertEqual(prepared.metadata.version, "3.2.1")
        XCTAssertEqual(prepared.metadata.buildNumber, "42")
        XCTAssertEqual(prepared.metadata.minimumOSVersion, "15.0")
        XCTAssertEqual(prepared.appBundleURL.lastPathComponent, "Demo.app")
        XCTAssertTrue(FileManager.default.fileExists(atPath: prepared.appBundleURL.path))

        let outputURL = directory.appendingPathComponent("Signed.ipa")
        try await service.package(appBundleURL: prepared.appBundleURL, to: outputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        let archive = try Archive(url: outputURL, accessMode: .read)
        let paths = archive.map(\.path)
        XCTAssertTrue(paths.contains("Payload/"))
        XCTAssertTrue(paths.contains("Payload/Demo.app/Info.plist"))
        XCTAssertTrue(paths.contains("Payload/Demo.app/Demo"))

        await service.discard(workspace: prepared.workspaceURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: prepared.workspaceURL.path))
    }

    func testRejectsArchiveWithoutPayload() async throws {
        let directory = try XCTUnwrap(root)
        let source = directory.appendingPathComponent("Source", isDirectory: true)
        let unrelated = source.appendingPathComponent("Other", isDirectory: true)
        try FileManager.default.createDirectory(at: unrelated, withIntermediateDirectories: true)
        try Data("hello".utf8).write(to: unrelated.appendingPathComponent("file.txt"))

        let ipaURL = directory.appendingPathComponent("NoPayload.ipa")
        try FileManager.default.zipItem(
            at: source,
            to: ipaURL,
            shouldKeepParent: true,
            compressionMethod: .deflate
        )

        let service = IPAService()
        let workspaceRoot = directory.appendingPathComponent("Workspaces")
        do {
            _ = try await service.prepare(ipaURL: ipaURL, workspaceRoot: workspaceRoot)
            XCTFail("Expected prepare to reject an archive without Payload.")
        } catch let error as OmnistoreError {
            guard case .invalidIPA(let message) = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
            XCTAssertFalse(message.isEmpty)
        }
    }

    func testRejectsPathTraversalEntries() async throws {
        let directory = try XCTUnwrap(root)
        let ipaURL = directory.appendingPathComponent("Traversal.ipa")
        let archive = try Archive(url: ipaURL, accessMode: .create)
        let data = Data("malicious".utf8)

        try archive.addEntry(
            with: "../escape.txt",
            type: .file,
            uncompressedSize: Int64(data.count),
            compressionMethod: .none
        ) { position, size in
            let start = Int(position)
            guard start < data.count else { return Data() }
            let end = min(data.count, start + size)
            return data.subdata(in: start..<end)
        }

        let service = IPAService()
        let workspaceRoot = directory.appendingPathComponent("Workspaces")
        do {
            _ = try await service.prepare(ipaURL: ipaURL, workspaceRoot: workspaceRoot)
            XCTFail("Expected prepare to reject a traversal entry.")
        } catch let error as OmnistoreError {
            guard case .invalidIPA(let message) = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
            let lowered = message.lowercased()
            XCTAssertTrue(lowered.contains("unsafe") || lowered.contains("outside"))
        }

        let escapedURL = directory.appendingPathComponent("escape.txt")
        XCTAssertFalse(FileManager.default.fileExists(atPath: escapedURL.path))
    }

    func testPrepareRejectsMissingFile() async throws {
        let directory = try XCTUnwrap(root)
        let missing = directory.appendingPathComponent("Missing.ipa")
        let service = IPAService()

        do {
            _ = try await service.prepare(ipaURL: missing, workspaceRoot: directory)
            XCTFail("Expected a missing-file error.")
        } catch let error as OmnistoreError {
            guard case .invalidIPA = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    // MARK: - Fixtures

    private func makeFixtureIPA(in directory: URL) throws -> URL {
        let payload = directory.appendingPathComponent("Fixture/Payload", isDirectory: true)
        let app = payload.appendingPathComponent("Demo.app", isDirectory: true)
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)

        let info: [String: Any] = [
            "CFBundleIdentifier": "com.example.demo",
            "CFBundleDisplayName": "Demo App",
            "CFBundleName": "Demo",
            "CFBundleShortVersionString": "3.2.1",
            "CFBundleVersion": "42",
            "MinimumOSVersion": "15.0",
        ]
        let infoData = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try infoData.write(to: app.appendingPathComponent("Info.plist"))
        try Data([0xCF, 0xFA, 0xED, 0xFE]).write(to: app.appendingPathComponent("Demo"))

        let ipaURL = directory.appendingPathComponent("Demo.ipa")
        try FileManager.default.zipItem(
            at: payload,
            to: ipaURL,
            shouldKeepParent: true,
            compressionMethod: .deflate
        )
        return ipaURL
    }
}
