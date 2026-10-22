//
//  OmnistoreError.swift
//  OmnistoreKit
//

import Foundation

public enum OmnistoreError: Error, LocalizedError, Sendable, Equatable {
    case storage(String)
    case invalidIPA(String)
    case signing(String)
    case installation(String)
    case authentication(String)
    case provisioning(String)
    case invalidConfiguration(String)
    case library(String)

    public var errorDescription: String? {
        switch self {
        case .storage(let reason):
            return "A file operation failed: \(reason)"
        case .invalidIPA(let reason):
            return "This IPA could not be unpacked: \(reason)"
        case .signing(let reason):
            return "Code signing failed: \(reason)"
        case .installation(let reason):
            return "Installation failed: \(reason)"
        case .authentication(let reason):
            return "Apple ID authentication failed: \(reason)"
        case .provisioning(let reason):
            return "Could not prepare the app for your device: \(reason)"
        case .invalidConfiguration(let reason):
            return reason
        case .library(let reason):
            return "The app library could not be updated: \(reason)"
        }
    }
}
