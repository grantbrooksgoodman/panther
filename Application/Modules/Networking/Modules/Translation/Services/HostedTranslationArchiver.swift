//
//  HostedTranslationArchiver.swift
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

public struct HostedTranslationArchiver {
    // MARK: - Dependencies

    @Dependency(\.localTranslationArchiver) private var localTranslationArchiver: LocalTranslationArchiverDelegate
    @Dependency(\.networking) private var networking: Networking

    // MARK: - Archive Recent Translations

    @discardableResult
    public func addRecentlyUploadedLocalizedTranslationsToLocalArchive() async -> Exception? {
        let languagePair: LanguagePair = .system
        let commonParams = ["LanguagePair": languagePair.string]

        guard !languagePair.isIdempotent else { return nil }

        if let exception = TranslationValidator.validate(
            languagePair: languagePair,
            metadata: [self, #file, #function, #line]
        ) {
            return exception.appending(extraParams: commonParams)
        }

        let queryValuesResult = await networking.database.queryValues(
            at: "\(networking.config.paths.translations)/\(languagePair.string)",
            strategy: .last(100)
        )

        switch queryValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: String] else {
                let exception: Exception = .typecastFailed("dictionary", metadata: [self, #file, #function, #line])
                return exception.appending(extraParams: commonParams)
            }

            for value in dictionary.values {
                guard let components = value.decodedTranslationComponents else {
                    let exception = Exception(
                        "Failed to decode translation.",
                        extraParams: ["Value": value],
                        metadata: [self, #file, #function, #line]
                    )
                    return exception.appending(extraParams: commonParams)
                }

                let decoded: Translation = .init(
                    input: .init(components.input),
                    output: components.output,
                    languagePair: languagePair
                )
                localTranslationArchiver.addValue(decoded)

                Logger.log(
                    .init(
                        "Added hosted translation to local archive.",
                        extraParams: ["ReferenceHostingKey": decoded.reference.hostingKey],
                        metadata: [self, #file, #function, #line]
                    ),
                    domain: .hostedTranslation
                )
            }

            return nil

        case let .failure(exception):
            return exception.appending(extraParams: commonParams)
        }
    }

    // MARK: - Find Archived Translations

    public func findArchivedTranslation(id: String, languagePair: LanguagePair) async -> Callback<Translation, Exception> {
        let path = "\(networking.config.paths.translations)/\(languagePair.string)/\(id)"
        let commonParams = ["Path": path]

        if let exception = TranslationValidator.validate(
            languagePair: languagePair,
            metadata: [self, #file, #function, #line]
        ) {
            return .failure(exception)
        }

        let getValuesResult = await networking.database.getValues(at: path)

        switch getValuesResult {
        case let .success(values):
            guard let value = values as? String else {
                let exception: Exception = .typecastFailed(
                    "string",
                    extraParams: ["Value": values],
                    metadata: [self, #file, #function, #line]
                )
                return .failure(exception.appending(extraParams: commonParams))
            }

            guard let components = value.decodedTranslationComponents else {
                let exception = Exception(
                    "Failed to decode translation.",
                    extraParams: ["Value": value],
                    metadata: [self, #file, #function, #line]
                )
                return .failure(exception.appending(extraParams: commonParams))
            }

            return .success(
                .init(
                    input: .init(components.input),
                    output: components.output,
                    languagePair: languagePair
                )
            )

        case let .failure(exception):
            return .failure(exception.appending(extraParams: commonParams))
        }
    }

    // MARK: - Remove Archived Translations

    @discardableResult
    public func removeArchivedTranslation(
        for input: TranslationInput,
        languagePair: LanguagePair
    ) async -> Exception? {
        let path = "\(networking.config.paths.translations)/\(languagePair.string)"

        if let exception = await networking.database.updateChildValues(
            forKey: path,
            with: [input.value.encodedHash: NSNull()]
        ) {
            return exception
        }

        return nil
    }

    // MARK: - Upload Translations to Archive

    @discardableResult
    public func addToHostedArchive(_ translation: Translation) async -> Exception? {
        if let exception = TranslationValidator.validate(
            translation: translation,
            metadata: [self, #file, #function, #line]
        ) {
            return exception
        }

        guard !translation.languagePair.isIdempotent,
              let referenceValue = translation.reference.type.value else {
            return .init(
                "Translation language pair is idempotent; ineligible for hosted archive.",
                metadata: [self, #file, #function, #line]
            )
        }

        let languagePairString = translation.languagePair.string

        if let exception = await networking.database.updateChildValues(
            forKey: "\(networking.config.paths.translations)/\(languagePairString)",
            with: [translation.reference.type.key: referenceValue]
        ) {
            return exception
        }

        Logger.log(
            .init(
                "Added retrieved translation to hosted archive.",
                extraParams: ["ReferenceHostingKey": translation.reference.hostingKey],
                metadata: [self, #file, #function, #line]
            ),
            domain: .hostedTranslation
        )

        return nil
    }
}
