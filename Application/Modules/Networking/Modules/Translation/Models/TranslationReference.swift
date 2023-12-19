//
//  TranslationReference.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Translator

public struct TranslationReference: Codable, Equatable {
    // MARK: - Types

    public enum `Type`: Codable, Equatable {
        case archived(_ hash: String)
        case idempotent(_ value: String)
    }

    // MARK: - Properties

    public let languagePair: LanguagePair
    public let type: `Type`

    // MARK: - Init

    public init(languagePair: LanguagePair, type: Type) {
        self.languagePair = languagePair
        self.type = type
    }

    public init?(_ string: String) {
        let isIdempotent = string.contains(TranslationConstants.idempotentPrefix)
        let components = string.components(separatedBy: " ")

        guard components.count == (isIdempotent ? 4 : 3),
              let languagePair = LanguagePair(components[isIdempotent ? 1 : 0]),
              let reference = components.last else { return nil }

        self.init(
            languagePair: languagePair,
            type: isIdempotent ? .idempotent(reference.base64Decoded) : .archived(reference)
        )
    }
}
