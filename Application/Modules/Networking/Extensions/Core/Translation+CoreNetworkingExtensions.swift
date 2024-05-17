//
//  Translation+CoreNetworkingExtensions.swift
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
        let sameLanguagePair = left.languagePair == right.languagePair
        let sameOutput = left.output == right.output

        guard sameInput,
              sameLanguagePair,
              sameOutput else { return false }

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
    var reference: TranslationReference {
        .init(self)
    }

    var withSanitizedOutput: Translation {
        .init(
            input: input,
            output: output.sanitized,
            languagePair: languagePair
        )
    }
}
