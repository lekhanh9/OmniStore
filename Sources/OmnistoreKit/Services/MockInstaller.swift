//
//  MockInstaller.swift
//  OmnistoreKit
//
//  Simulates the on-device install while Minimuxer is being bridged.
//

import Foundation

public final class MockInstaller: InstallerProtocol, @unchecked Sendable {
    private struct Configuration {
        var delay: TimeInterval
        var shouldFail: Bool
    }

    private let lock = NSLock()
    private var configuration: Configuration

    public var isMock: Bool { true }

    public init(simulatedDelay: TimeInterval = 1.2, shouldFail: Bool = false) {
        self.configuration = Configuration(
            delay: max(0, simulatedDelay),
            shouldFail: shouldFail
        )
    }

    public func configure(simulatedDelay: TimeInterval, shouldFail: Bool) {
        lock.lock()
        configuration = Configuration(delay: max(0, simulatedDelay), shouldFail: shouldFail)
        lock.unlock()
    }

    public func installApp(
        ipaURL: URL,
        progressHandler: (@Sendable (Double) -> Void)?
    ) async throws {
        guard FileManager.default.fileExists(atPath: ipaURL.path) else {
            throw OmnistoreError.installation("The packaged IPA is missing at \(ipaURL.lastPathComponent).")
        }

        let current = currentConfiguration()
        guard !current.shouldFail else {
            throw OmnistoreError.installation("The mock installer was configured to fail. Disable “Force failure” in Settings and try again.")
        }

        let steps = 10
        let stepDuration = current.delay / Double(steps)

        for step in 1...steps {
            try Task.checkCancellation()
            progressHandler?(Double(step) / Double(steps))
            if stepDuration > 0 {
                try await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
            }
        }
    }

    public func uninstallApp(bundleIdentifier: String) async throws {
        let current = currentConfiguration()
        guard !current.shouldFail else {
            throw OmnistoreError.installation("The mock installer was configured to fail.")
        }

        let delay = min(current.delay, 0.4)
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        try Task.checkCancellation()
        _ = bundleIdentifier
    }

    private func currentConfiguration() -> Configuration {
        lock.lock()
        let value = configuration
        lock.unlock()
        return value
    }
}
