//
//  Translation+NetworkingExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Translator

extension Translation: Equatable {
    public static func == (left: Translation, right: Translation) -> Bool {
        let sameInput = left.input == right.input
        let sameOutput = left.output == right.output
        let sameLanguagePair = left.languagePair == right.languagePair

        guard sameInput,
              sameOutput,
              sameLanguagePair else { return false }

        return true
    }
}

extension Translation: Validatable {
    public var isWellFormed: Bool {
        let isInputValid = input.isWellFormed
        let isOutputValid = TranslationInput(output).isWellFormed
        let isLanguagePairValid = languagePair.isWellFormed
        return isInputValid && isOutputValid && isLanguagePairValid
    }
}

public extension Translation {
    var serialized: [String: String] {
        let value = input.value()
        return ["\(value.compressedHash)": "\(value.alphaEncoded)–\(output.matchingCapitalization(of: value).alphaEncoded)"]
    }

    var withSanitizedOutput: Translation {
        .init(
            input: input,
            output: output.sanitized,
            languagePair: languagePair
        )
    }
}
