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
import CoreArchitecture
import Translator

extension Translation: Serializable {
    // MARK: - Type Aliases

    public typealias T = Translation

    // MARK: - Properties

    public var encoded: TranslationReference { .init(self) }

    // MARK: - Methods

    public static func canDecode(from data: TranslationReference) -> Bool { true }

    public static func decode(from data: TranslationReference) async -> Callback<Translation, Exception> {
        @Dependency(\.networking.services.translation.archiver) var translationArchiver: HostedTranslationArchiver

        func addToArchive(_ translation: Translation) {
            guard translation.input.value() != translation.output else { return }
            TranslationArchiver.addToArchive(translation.withSanitizedOutput)
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

            // FIXME: Experienced crash here. Consider using await MainActor.run.
            if let archivedTranslation = TranslationArchiver.getFromArchive(
                withReference: hash,
                languagePair: data.languagePair
            ) {
                return .success(archivedTranslation.withSanitizedOutput)
            }

            let findArchivedTranslationResult = await translationArchiver.findArchivedTranslation(
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
            return .success(.init(
                input: .init(encodedValue.base64Decoded),
                output: encodedValue.base64Decoded,
                languagePair: data.languagePair
            ))
        }
    }
}
