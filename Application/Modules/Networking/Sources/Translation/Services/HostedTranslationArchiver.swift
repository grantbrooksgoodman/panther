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
import Networking
import Translator

// swiftlint:disable:next type_body_length
public final class HostedTranslationArchiver {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.localTranslationArchiver) private var localTranslationArchiver: LocalTranslationArchiverDelegate
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Properties

    private var isPopulatingTranslationDataSnapshot = false
    private var translationDataSnapshot: TranslationDataSnapshot = .empty

    // MARK: - Init

    public init() {
        Task {
            guard let exception = await populateTranslationDataSnapshot(expiryThreshold: .seconds(300)) else {
                return Logger.log(
                    "Populated translation data snapshot.",
                    domain: .hostedTranslation,
                    metadata: [self, #file, #function, #line]
                )
            }

            Logger.log(
                exception,
                domain: .hostedTranslation,
                with: .toastInPrerelease
            )
        }
    }

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
            at: "\(NetworkPath.translations.rawValue)/\(languagePair.string)",
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

    public func findArchivedTranslation(
        input: TranslationInput,
        languagePair: LanguagePair
    ) async -> Callback<Translation, Exception> {
        let findArchivedTranslationResult = await findArchivedTranslation(
            id: input.value.encodedHash,
            languagePair: languagePair
        )

        switch findArchivedTranslationResult {
        case let .success(translation):
            return .success(translation)

        case let .failure(exception):
            guard exception.isEqual(to: .Networking.Database.noValueExists) else { return .failure(exception) }
            return await deriveTranslation(input: input, languagePair: languagePair)
        }
    }

    public func findArchivedTranslation(
        id: String,
        languagePair: LanguagePair
    ) async -> Callback<Translation, Exception> {
        let path = "\(NetworkPath.translations.rawValue)/\(languagePair.string)/\(id)"
        let commonParams = ["Path": path]

        if let exception = TranslationValidator.validate(
            languagePair: languagePair,
            metadata: [self, #file, #function, #line]
        ) {
            return .failure(exception.appending(extraParams: commonParams))
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
        let path = "\(NetworkPath.translations.rawValue)/\(languagePair.string)"

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
            forKey: "\(NetworkPath.translations.rawValue)/\(languagePairString)",
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

    // MARK: - Auxiliary

    private func deriveTranslation(
        input originalInput: TranslationInput,
        languagePair originalLanguagePair: LanguagePair
    ) async -> Callback<Translation, Exception> {
        if let exception = await populateTranslationDataSnapshot() {
            return .failure(exception)
        }

        let originalInputHash = originalInput.value.encodedHash
        for (archivedLanguagePairData, archivedTranslationData) in translationDataSnapshot.data {
            guard let archivedLanguagePair = LanguagePair(archivedLanguagePairData),
                  let sourceLanguageTranslationData = archivedTranslationData as? [String: String],
                  let sourceLanguageTranslation = sourceLanguageTranslationData.first(where: { $0.key == originalInputHash }),
                  let sourceLanguageTranslationComponents = sourceLanguageTranslation.value.decodedTranslationComponents,
                  let targetLanguageTranslationData = translationDataSnapshot.data["\(archivedLanguagePair.to)-\(originalLanguagePair.to)"],
                  let targetLanguageTranslation = targetLanguageTranslationData[sourceLanguageTranslationComponents.output.encodedHash] as? String,
                  let targetLanguageTranslationComponents = targetLanguageTranslation.decodedTranslationComponents else { continue }

            let derivedTranslation = Translation(
                input: .init(originalInput.value),
                output: targetLanguageTranslationComponents.output,
                languagePair: originalLanguagePair
            )

            if !derivedTranslation.languagePair.isIdempotent,
               let exception = await addToHostedArchive(derivedTranslation) {
                return .failure(exception)
            }

            if build.milestone != .generalRelease {
                Logger.log(
                    .init(
                        "Successfully derived translation from existing data.",
                        isReportable: false,
                        extraParams: [
                            "IntermediateLanguagePair": archivedLanguagePair.string,
                            "SynthesisLanguagePair": "\(archivedLanguagePair.to)-\(originalLanguagePair.to)",
                            "TargetLanguagePair": originalLanguagePair.string,
                        ],
                        metadata: [self, #file, #function, #line]
                    ),
                    domain: .hostedTranslation,
                    with: .toast(style: .success, isPersistent: true)
                )
            }

            return .success(derivedTranslation)
        }

        return .failure(.init(
            "Failed to derive translation from existing data.",
            metadata: [self, #file, #function, #line]
        ))
    }

    private func populateTranslationDataSnapshot(expiryThreshold: Duration = .seconds(120)) async -> Exception? {
        guard !isPopulatingTranslationDataSnapshot,
              translationDataSnapshot.isExpired || translationDataSnapshot == .empty else { return nil }

        isPopulatingTranslationDataSnapshot = true
        let getValuesResult = await networking.database.getValues(at: NetworkPath.translations.rawValue)

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: [String: Any]] else {
                isPopulatingTranslationDataSnapshot = false
                return .typecastFailed(
                    "dictionary",
                    metadata: [self, #file, #function, #line]
                )
            }

            for (key, value) in dictionary {
                for (translationKey, translationValue) in value {
                    CoreDatabaseCache.addValue(
                        .init(
                            data: translationValue,
                            expiresAfter: .seconds(600)
                        ),
                        forKey: "\(Networking.config.environment.shortString)/\(NetworkPath.translations.rawValue)/\(key)/\(translationKey)"
                    )
                }
            }

            translationDataSnapshot = .init(data: dictionary, expiryThreshold: expiryThreshold)
            isPopulatingTranslationDataSnapshot = false
            return nil

        case let .failure(exception):
            isPopulatingTranslationDataSnapshot = false
            return exception
        }
    }
}
