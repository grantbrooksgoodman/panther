//
//  HostedTranslationService.swift
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

public struct HostedTranslationService {
    // MARK: - Dependencies

    @Dependency(\.localTranslationArchiver) private var localTranslationArchiver: LocalTranslationArchiverDelegate
    @Dependency(\.translationService) private var translator: TranslationService

    // MARK: - Properties

    public let archiver: HostedTranslationArchiver
    public let languageRecognition: LanguageRecognitionService
    public let legacy: LegacyTranslationService

    // MARK: - Init

    public init(
        archiver: HostedTranslationArchiver,
        languageRecognition: LanguageRecognitionService,
        legacy: LegacyTranslationService
    ) {
        self.archiver = archiver
        self.languageRecognition = languageRecognition
        self.legacy = legacy
    }

    // MARK: - Label String Resolution

    public func resolve(_ strings: TranslatedLabelStrings.Type) async -> Callback<[TranslationOutputMap], Exception> {
        guard LanguagePair.system.isWellFormed,
              !LanguagePair.system.isIdempotent else {
            return .success(strings.defaultOutputMap)
        }

        let getTranslationsResult = await getTranslations(for: strings.keyPairs.map(\.input), languagePair: .system)

        switch getTranslationsResult {
        case let .success(translations):
            let outputs = strings.keyPairs.reduce(into: [TranslationOutputMap]()) { partialResult, keyPair in
                if let translation = translations.first(where: { $0.input.value == keyPair.input.value }) {
                    partialResult.append(.init(key: keyPair.key, value: translation.output))
                } else {
                    partialResult.append(keyPair.defaultOutputMap)
                }
            }
            return .success(outputs)

        case let .failure(error):
            return .failure(error)
        }
    }

    // MARK: - Translation

    public func getTranslations(
        for inputs: [TranslationInput],
        languagePair: LanguagePair,
        hud hudConfig: (appearsAfter: Duration, isModal: Bool)? = nil
    ) async -> Callback<[Translation], Exception> {
        if let exception = TranslationValidator.validate(
            inputs: inputs,
            languagePair: languagePair,
            metadata: [self, #file, #function, #line]
        ) {
            return .failure(exception)
        }

        var translations = [Translation]()

        for input in inputs {
            let translateResult = await translate(
                input,
                with: languagePair,
                hud: hudConfig
            )

            switch translateResult {
            case let .success(translation):
                translations.append(translation)

            case let .failure(exception):
                return .failure(exception)
            }
        }

        guard translations.count == inputs.count else {
            return .failure(.init("Mismatched translation input/output.", metadata: [self, #file, #function, #line]))
        }

        return .success(translations)
    }

    // swiftlint:disable:next function_body_length
    public func translate(
        _ input: TranslationInput,
        with languagePair: LanguagePair,
        hud hudConfig: (appearsAfter: Duration, isModal: Bool)? = nil
    ) async -> Callback<Translation, Exception> {
        let input = input.withTaggedDetectorAttributes

        if let exception = TranslationValidator.validate(
            inputs: [input],
            languagePair: languagePair,
            metadata: [self, #file, #function, #line]
        ) {
            return .failure(exception)
        }

        if languagePair.isIdempotent {
            let translation: Translation = .init(
                input: input,
                output: input.value.sanitized,
                languagePair: languagePair
            )

            return .success(translation)
        }

        if let archivedTranslation = localTranslationArchiver.getValue(
            inputValueEncodedHash: input.value.encodedHash,
            languagePair: languagePair
        ) {
            if TranslationValidator.validate(
                translation: archivedTranslation,
                metadata: [self, #file, #function, #line]
            ) != nil || archivedTranslation.input.value == archivedTranslation.output {
                localTranslationArchiver.removeValue(
                    inputValueEncodedHash: input.value.encodedHash,
                    languagePair: languagePair
                )
                return await translate(
                    input,
                    with: languagePair,
                    hud: hudConfig
                )
            }

            return .success(archivedTranslation)
        }

        let sameInputOutputLanguage = await languageRecognition.matchConfidence(for: input.value, inLanguage: languagePair.to) > 0.8
        let hasUnicodeLetters = input.value.rangeOfCharacter(from: .letters) != nil

        if sameInputOutputLanguage || !hasUnicodeLetters {
            let translation: Translation = .init(
                input: input,
                output: input.value.sanitized,
                languagePair: languagePair
            )

            await archiver.addToHostedArchive(translation)
            localTranslationArchiver.addValue(translation)
            return .success(translation)
        }

        let findArchivedTranslationResult = await archiver.findArchivedTranslation(
            id: input.value.encodedHash,
            languagePair: languagePair
        )

        switch findArchivedTranslationResult {
        case let .success(translation):
            if TranslationValidator.validate(
                translation: translation,
                metadata: [self, #file, #function, #line]
            ) != nil || translation.input.value == translation.output {
                await archiver.removeArchivedTranslation(for: input, languagePair: languagePair)
                return await translate(
                    input,
                    with: languagePair,
                    hud: hudConfig
                )
            }

            guard translation.input.value != translation.output else { return .success(translation) }
            localTranslationArchiver.addValue(translation)
            return .success(translation)

        case let .failure(exception):
            guard exception.isEqual(to: .noValueExists) else {
                return .failure(exception)
            }

            let sourceLanguageName = languagePair.from.englishLanguageName ?? languagePair.from.uppercased()
            let targetLanguageName = languagePair.to.englishLanguageName ?? languagePair.to.uppercased()
            Logger.log(
                .init(
                    "Translating text from \(sourceLanguageName) to \(targetLanguageName).",
                    extraParams: ["InputValue": input.value,
                                  "LanguagePair": languagePair.string],
                    metadata: [self, #file, #function, #line]
                ),
                domain: .hostedTranslation
            )

            let translateResult = await translator.translate(
                .init(
                    input.value.trimmingTrailingWhitespace,
                    alternate: input.alternate?.trimmingTrailingWhitespace
                ),
                languagePair: languagePair,
                hud: hudConfig,
                timeout: (.seconds(10), false)
            )

            switch translateResult {
            case let .success(translation):
                let translation: Translation = .init(
                    input: input,
                    output: translation.output,
                    languagePair: translation.languagePair
                )

                if let exception = TranslationValidator.validate(
                    translation: translation,
                    metadata: [self, #file, #function, #line]
                ) {
                    return .failure(exception)
                }

                await archiver.addToHostedArchive(translation)
                guard translation.input.value != translation.output else { return .success(translation) }

                localTranslationArchiver.addValue(translation)
                return .success(translation)

            case let .failure(exception):
                guard exception.isEqual(toAny: [.exhaustedAvailablePlatforms,
                                                .sameTranslationInputOutput]) else {
                    return .failure(exception)
                }

                let translation: Translation = .init(
                    input: input,
                    output: input.value.sanitized,
                    languagePair: languagePair
                )

                await archiver.addToHostedArchive(translation)
                guard translation.input.value != translation.output else { return .success(translation) }

                localTranslationArchiver.addValue(translation)
                return .success(translation)
            }
        }
    }
}
