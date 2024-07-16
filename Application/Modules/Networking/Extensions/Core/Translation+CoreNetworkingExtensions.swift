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
