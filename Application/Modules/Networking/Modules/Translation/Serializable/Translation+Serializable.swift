//
//  Translation+Serializable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking
import Translator

extension Translation: Serializable {
    // MARK: - Type Aliases

    public typealias T = Translation

    // MARK: - Properties

    public var encoded: TranslationReference { .init(self) }

    // MARK: - Methods

    public static func canDecode(from data: TranslationReference) -> Bool { true }

    public static func decode(from data: TranslationReference) async -> Callback<Translation, Exception> {
        @Dependency(\.networking.translationService.archiver) var hostedTranslationArchiver: HostedTranslationArchiver
        @Dependency(\.localTranslationArchiver) var localTranslationArchiver: LocalTranslationArchiverDelegate

        func addToArchive(_ translation: Translation) {
            guard translation.input.value != translation.output else { return }
            localTranslationArchiver.addValue(translation)
        }

        switch data.type {
        case let .archived(hash, value: value):
            if let value {
                let components = value.components(separatedBy: "–")
                guard components.count == 2,
                      let inputString = components[0].removingPercentEncoding,
                      let outputString = components[1].removingPercentEncoding else {
                    return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
                }

                let decoded: Translation = .init(
                    input: .init(inputString),
                    output: outputString,
                    languagePair: data.languagePair
                )

                addToArchive(decoded)
                return .success(decoded)
            }

            if let archivedTranslation = localTranslationArchiver.getValue(
                inputValueEncodedHash: hash,
                languagePair: data.languagePair
            ) {
                return .success(archivedTranslation)
            }

            let findArchivedTranslationResult = await hostedTranslationArchiver.findArchivedTranslation(
                id: hash,
                languagePair: data.languagePair
            )

            switch findArchivedTranslationResult {
            case let .success(translation):
                addToArchive(translation)
                return .success(translation)

            case let .failure(exception):
                return .failure(exception)
            }

        case let .idempotent(encodedValue):
            let decoded: Translation = .init(
                input: .init(encodedValue.base64Decoded),
                output: encodedValue.base64Decoded.sanitized,
                languagePair: data.languagePair
            )

            addToArchive(decoded)
            return .success(decoded)
        }
    }
}
