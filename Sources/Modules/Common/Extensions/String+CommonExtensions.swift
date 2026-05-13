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

    var localized: String {
        @Dependency(\.translationArchiverDelegate) var translationArchive: TranslationArchiverDelegate

        return translationArchive.getValue(
            inputValueEncodedHash: encodedHash,
            languagePair: .system
        )?.output.sanitized ?? self
    }

    var shortCode: String { "\(prefix(2))\(suffix(2))".uppercased() }
    /// Prefixes the string to its first 32 characters.
    var shortened: String { .init(prefix(32)) }

    // MARK: - Methods

    static func fromCurrentEditorContext(
        sender: Any,
        function: String = #function
    ) -> String {
        "\(String(sender)).\(function)"
    }
}
