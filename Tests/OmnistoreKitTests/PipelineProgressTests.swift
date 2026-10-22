import XCTest
@testable import OmnistoreKit

final class PipelineProgressTests: XCTestCase {
    func testFractionIsClamped() {
        let low = PipelineProgress(stage: .signing, fraction: -0.4, message: "Low")
        let high = PipelineProgress(stage: .signing, fraction: 1.6, message: "High")

        XCTAssertEqual(low.fraction, 0)
        XCTAssertEqual(high.fraction, 1)
    }

    func testStageFlags() {
        XCTAssertTrue(InstallationStage.installing.isActive)
        XCTAssertFalse(InstallationStage.completed.isActive)
        XCTAssertTrue(InstallationStage.completed.isTerminal)
        XCTAssertTrue(InstallationStage.failed.isTerminal)
        XCTAssertFalse(InstallationStage.idle.isActive)
    }

    func testFailureCarriesDescription() {
        let progress = PipelineProgress.failed("Archive was malformed.")
        XCTAssertEqual(progress.stage, .failed)
        XCTAssertEqual(progress.errorDescription, "Archive was malformed.")
        XCTAssertEqual(progress.message, "Installation stopped")
    }

    func testCompletedHasFullFraction() {
        let progress = PipelineProgress.completed("Done")
        XCTAssertEqual(progress.stage, .completed)
        XCTAssertEqual(progress.fraction, 1)
        XCTAssertNil(progress.errorDescription)
    }
}
