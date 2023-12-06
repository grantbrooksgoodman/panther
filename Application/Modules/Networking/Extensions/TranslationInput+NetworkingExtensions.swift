//
//  TranslationInput+NetworkingExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Translator

extension TranslationInput: Validatable {
    public var isWellFormed: Bool {
        let notBlank = !value().isBlank
        let hasUnicodeLetters = value().rangeOfCharacter(from: .letters) != nil
        return notBlank && hasUnicodeLetters
    }
}
