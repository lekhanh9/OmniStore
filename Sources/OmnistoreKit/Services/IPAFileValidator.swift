//
//  IPAFileValidator.swift
//  OmnistoreKit
//

import Foundation

public enum IPAFileValidator {
    public static func validate(_ url: URL, fileManager: FileManager = .default) throws {
        guard url.isFileURL else {
            throw OmnistoreError.invalidIPA("Choose an IPA file from the Files app.")
        }
        guard url.pathExtension.lowercased() == "ipa" else {
            throw OmnistoreError.invalidIPA("The selected file does not have a .ipa extension.")
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            throw OmnistoreError.invalidIPA("The selected IPA no longer exists.")
        }

        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile != false else {
                throw OmnistoreError.invalidIPA("The selected file is not a regular file.")
            }
            guard let fileSize = values.fileSize, fileSize > 0 else {
                throw OmnistoreError.invalidIPA("The selected IPA is empty.")
            }
        } catch let known as OmnistoreError {
            throw known
        } catch {
            throw OmnistoreError.invalidIPA(
                "The selected file could not be inspected: \(error.localizedDescription)"
            )
        }
    }
}
