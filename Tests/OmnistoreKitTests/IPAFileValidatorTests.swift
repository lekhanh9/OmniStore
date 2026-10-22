import XCTest
@testable import OmnistoreKit

final class IPAFileValidatorTests: XCTestCase {
    private var root: URL?

    override func setUpWithError() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OmnistoreValidatorTests-\(UUID().uuidString)", isDirectory: true)
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

    func testAcceptsNonEmptyIPA() throws {
        let directory = try XCTUnwrap(root)
        let url = directory.appendingPathComponent("Sample.ipa")
        try Data("PK".utf8).write(to: url)

        XCTAssertNoThrow(try IPAFileValidator.validate(url))
    }

    func testAcceptsUppercaseExtension() throws {
        let directory = try XCTUnwrap(root)
        let url = directory.appendingPathComponent("Sample.IPA")
        try Data("PK".utf8).write(to: url)

        XCTAssertNoThrow(try IPAFileValidator.validate(url))
    }

    func testRejectsNonIPAExtension() throws {
        let directory = try XCTUnwrap(root)
        let url = directory.appendingPathComponent("Notes.txt")
        try Data("hello".utf8).write(to: url)

        assertInvalidIPA(try IPAFileValidator.validate(url))
    }

    func testRejectsEmptyIPA() throws {
        let directory = try XCTUnwrap(root)
        let url = directory.appendingPathComponent("Empty.ipa")
        try Data().write(to: url)

        assertInvalidIPA(try IPAFileValidator.validate(url))
    }

    func testRejectsMissingFile() throws {
        let directory = try XCTUnwrap(root)
        let url = directory.appendingPathComponent("Missing.ipa")

        assertInvalidIPA(try IPAFileValidator.validate(url))
    }

    func testRejectsDirectoryNamedIPA() throws {
        let directory = try XCTUnwrap(root)
        let url = directory.appendingPathComponent("Folder.ipa", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        assertInvalidIPA(try IPAFileValidator.validate(url))
    }

    func testPrepareRejectsTXTBeforeUnzipping() async throws {
        let directory = try XCTUnwrap(root)
        let url = directory.appendingPathComponent("Notes.txt")
        try Data("not an archive".utf8).write(to: url)

        let service = IPAService()
        do {
            _ = try await service.prepare(ipaURL: url, workspaceRoot: directory)
            XCTFail("Expected prepare to reject a non-IPA file.")
        } catch let error as OmnistoreError {
            guard case .invalidIPA = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
        let leftovers = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(leftovers.map(\.lastPathComponent), ["Notes.txt"])
    }

    private func assertInvalidIPA(
        _ expression: @autoclosure () throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            try expression()
            XCTFail("Expected validation to fail.", file: file, line: line)
        } catch let error as OmnistoreError {
            guard case .invalidIPA = error else {
                XCTFail("Unexpected error: \(error)", file: file, line: line)
                return
            }
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }
}
