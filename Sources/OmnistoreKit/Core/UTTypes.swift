//
//  UTTypes.swift
//  OmnistoreKit
//

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers

public extension UTType {
    static var ipa: UTType {
        UTType(filenameExtension: "ipa")
            ?? UTType(importedAs: "com.omnistore.ipa", conformingTo: .zip)
    }
}
#endif
