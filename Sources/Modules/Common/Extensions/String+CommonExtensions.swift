//
//  String+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Translator

extension String {
    // MARK: - Properties

    /// A localized representation of the string, resolved from the translation archive.
    ///
    /// This property looks up an archived translation of the string targeting the system
    /// language and returns its output. If no archived translation exists, it returns the string
    /// unchanged.
    var localized: String {
        @Dependency(\.translationArchiverDelegate) var translationArchive: TranslationArchiverDelegate

        return translationArchive.getValue(
            inputValueEncodedHash: encodedHash,
            languagePair: .system
        )?.output.sanitized ?? self
    }

    /// A four-character code composed of the string's first two and last two characters,
    /// uppercased.
    ///
    /// Use this property to display a compact reference to a long identifier.
    var shortCode: String {
        "\(prefix(2))\(suffix(2))".uppercased()
    }

    /// The first 32 characters of the string.
    ///
    /// If the string contains 32 or fewer characters, this property returns the string
    /// unchanged.
    var shortened: String {
        .init(prefix(32))
    }
}
