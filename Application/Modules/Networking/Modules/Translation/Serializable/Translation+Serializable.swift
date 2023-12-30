//
//  Translation+Serializable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux
import Translator

extension Translation: Serializable {
    // MARK: - Type Aliases

    public typealias T = Translation

    // MARK: - Properties

    public var encoded: TranslationReference { .init(self) }

    // MARK: - Methods

    public static func decode(from data: TranslationReference) async -> Callback<Translation, Exception> {
        @Dependency(\.networking.services.translation.archiver) var translationArchiver: HostedTranslationArchiver

        switch data.type {
        case let .archived(hash, value: value):
            if let value {
                let components = value.components(separatedBy: "–")
                guard components.count == 2,
                      let inputString = components[0].removingPercentEncoding,
                      let outputString = components[1].removingPercentEncoding else {
                    return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
                }

                return .success(.init(
                    input: .init(inputString),
                    output: outputString,
                    languagePair: data.languagePair
                ))
            }

            let findArchivedTranslationResult = await translationArchiver.findArchivedTranslation(
                id: hash,
                languagePair: data.languagePair
            )

            switch findArchivedTranslationResult {
            case let .success(translation):
                return .success(translation)

            case let .failure(exception):
                return .failure(exception)
            }

        case let .idempotent(encodedValue):
            return .success(.init(
                input: .init(encodedValue.base64Decoded),
                output: encodedValue.base64Decoded,
                languagePair: data.languagePair
            ))
        }
    }
}
