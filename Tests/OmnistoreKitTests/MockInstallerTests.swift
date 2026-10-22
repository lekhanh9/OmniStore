import XCTest
@testable import OmnistoreKit

final class MockInstallerTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
            } catch {
                XCTFail("Could not remove test file: \(error)")
            }
        }
        temporaryFiles.removeAll()
    }

    func testInstallReportsProgressAndCompletes() async throws {
        let installer = MockInstaller(simulatedDelay: 0)
        let ipaURL = try makeTemporaryIPA()
        let box = ProgressBox()

        try await installer.installApp(ipaURL: ipaURL) { fraction in
            box.append(fraction)
        }

        let values = box.values
        XCTAssertEqual(values.count, 10)
        XCTAssertEqual(values.first, 0.1)
        XCTAssertEqual(values.last, 1.0)
        XCTAssertTrue(values == values.sorted())
    }

    func testInstallThrowsWhenConfiguredToFail() async throws {
        let installer = MockInstaller(simulatedDelay: 0, shouldFail: true)
        let ipaURL = try makeTemporaryIPA()

        do {
            try await installer.installApp(ipaURL: ipaURL, progressHandler: nil)
            XCTFail("Expected the mock installer to throw.")
        } catch let error as OmnistoreError {
            guard case .installation = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    func testInstallThrowsWhenIPAIsMissing() async {
        let installer = MockInstaller(simulatedDelay: 0)
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).ipa")

        do {
            try await installer.installApp(ipaURL: missing, progressHandler: nil)
            XCTFail("Expected a missing-file error.")
        } catch let error as OmnistoreError {
            guard case .installation = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testConfigurationCanBeUpdated() async throws {
        let installer = MockInstaller(simulatedDelay: 0)
        let ipaURL = try makeTemporaryIPA()

        installer.configure(simulatedDelay: 0, shouldFail: true)

        do {
            try await installer.installApp(ipaURL: ipaURL, progressHandler: nil)
            XCTFail("Expected failure after reconfiguration.")
        } catch let error as OmnistoreError {
            guard case .installation = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    func testUninstallSucceedsWithZeroDelay() async throws {
        let installer = MockInstaller(simulatedDelay: 0)
        try await installer.uninstallApp(bundleIdentifier: "com.example.app")
    }

    private func makeTemporaryIPA() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mock-\(UUID().uuidString).ipa")
        try Data([0x50, 0x4B, 0x03, 0x04]).write(to: url)
        temporaryFiles.append(url)
        return url
    }
}

private final class ProgressBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValues: [Double] = []

    var values: [Double] {
        lock.lock()
        defer { lock.unlock() }
        return storedValues
    }

    func append(_ value: Double) {
        lock.lock()
        storedValues.append(value)
        lock.unlock()
    }
}
