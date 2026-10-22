//
//  PipelineProgress.swift
//  OmnistoreKit
//

import Foundation

public enum InstallationStage: String, Sendable, Equatable {
    case idle
    case preparing
    case provisioning
    case signing
    case packaging
    case installing
    case completed
    case failed

    public var title: String {
        switch self {
        case .idle: return "Ready"
        case .preparing: return "Preparing"
        case .provisioning: return "Provisioning"
        case .signing: return "Signing"
        case .packaging: return "Packaging"
        case .installing: return "Installing"
        case .completed: return "Installed"
        case .failed: return "Installation failed"
        }
    }

    public var isTerminal: Bool {
        self == .completed || self == .failed
    }

    public var isActive: Bool {
        self != .idle && !isTerminal
    }
}

public struct PipelineProgress: Sendable, Equatable {
    public let stage: InstallationStage
    public let fraction: Double
    public let message: String
    public let errorDescription: String?

    public init(
        stage: InstallationStage,
        fraction: Double,
        message: String,
        errorDescription: String? = nil
    ) {
        self.stage = stage
        self.fraction = min(max(fraction, 0), 1)
        self.message = message
        self.errorDescription = errorDescription
    }

    public static var idle: PipelineProgress {
        PipelineProgress(stage: .idle, fraction: 0, message: "Ready to install")
    }

    public static func preparing(_ fraction: Double, _ message: String) -> PipelineProgress {
        PipelineProgress(stage: .preparing, fraction: fraction, message: message)
    }

    public static func provisioning(_ fraction: Double, _ message: String) -> PipelineProgress {
        PipelineProgress(stage: .provisioning, fraction: fraction, message: message)
    }

    public static func signing(_ fraction: Double, _ message: String) -> PipelineProgress {
        PipelineProgress(stage: .signing, fraction: fraction, message: message)
    }

    public static func packaging(_ fraction: Double, _ message: String) -> PipelineProgress {
        PipelineProgress(stage: .packaging, fraction: fraction, message: message)
    }

    public static func installing(_ fraction: Double, _ message: String) -> PipelineProgress {
        PipelineProgress(stage: .installing, fraction: fraction, message: message)
    }

    public static func completed(_ message: String) -> PipelineProgress {
        PipelineProgress(stage: .completed, fraction: 1, message: message)
    }

    public static func failed(_ message: String) -> PipelineProgress {
        PipelineProgress(stage: .failed, fraction: 0, message: "Installation stopped", errorDescription: message)
    }
}
