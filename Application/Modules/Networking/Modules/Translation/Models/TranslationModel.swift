//
//  TranslationModel.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Translator

public struct TranslationModel: Codable, Equatable {
    // MARK: - Properties

    // String
    public let key: String
    public let value: String?

    // LanguagePair
    public let languagePair: LanguagePair

    // MARK: - Computed Properties

    public var referenceKey: String {
        "\(languagePair.isIdempotent ? "\(TranslationConstants.idempotentPrefix)\(languagePair.from)" : languagePair.asString()) | \(key)"
    }

    // MARK: - Init

    public init(
        languagePair: LanguagePair,
        key: String,
        value: String?
    ) {
        self.languagePair = languagePair
        self.key = key
        self.value = value
    }

    public init(_ translation: Translation) {
        let input = translation.input.value()

        if translation.languagePair.isIdempotent {
            self.init(
                languagePair: translation.languagePair,
                key: input.base64Encoded,
                value: nil
            )
        } else {
            self.init(
                languagePair: translation.languagePair,
                key: input.compressedHash,
                value: "\(input.alphaEncoded)–\(translation.output.matchingCapitalization(of: input).alphaEncoded)"
            )
        }
    }
}
