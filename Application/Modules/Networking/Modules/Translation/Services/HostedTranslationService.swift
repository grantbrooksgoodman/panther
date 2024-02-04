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
import Redux
import Translator

public struct HostedTranslationService {
    // MARK: - Dependencies

    @Dependency(\.translatorService) private var translator: TranslatorService

    // MARK: - Properties

    public let archiver: HostedTranslationArchiver
    public let legacy: LegacyTranslationService

    // MARK: - Init

    public init(archiver: HostedTranslationArchiver, legacy: LegacyTranslationService) {
        self.archiver = archiver
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
                if let translation = translations.first(where: { $0.input.value() == keyPair.input.value() }) {
                    partialResult.append(.init(key: keyPair.key, value: translation.output.sanitized))
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
                translations.append(translation.withSanitizedOutput)

            case let .failure(exception):
                return .failure(exception)
            }
        }

        guard translations.count == inputs.count else {
            return .failure(.init("Mismatched translation input/output.", metadata: [self, #file, #function, #line]))
        }

        return .success(translations)
    }

    public func translate(
        _ input: TranslationInput,
        with languagePair: LanguagePair,
        hud hudConfig: (appearsAfter: Duration, isModal: Bool)? = nil
    ) async -> Callback<Translation, Exception> {
        if let exception = TranslationValidator.validate(
            inputs: [input],
            languagePair: languagePair,
            metadata: [self, #file, #function, #line]
        ) {
            return .failure(exception)
        }

        if languagePair.isIdempotent {
            return .success(.init(
                input: input,
                output: input.value().sanitized,
                languagePair: languagePair
            ))
        }

        if let archivedTranslation = TranslationArchiver.getFromArchive(input, languagePair: languagePair) {
            if TranslationValidator.validate(
                translation: archivedTranslation,
                metadata: [self, #file, #function, #line]
            ) != nil {
                TranslationArchiver.clearArchive()
                return await translate(
                    input,
                    with: languagePair,
                    hud: hudConfig
                )
            }

            return .success(archivedTranslation.withSanitizedOutput)
        }

        let findArchivedTranslationResult = await archiver.findArchivedTranslation(
            id: input.value().encodedHash,
            languagePair: languagePair
        )

        switch findArchivedTranslationResult {
        case let .success(translation):
            if TranslationValidator.validate(
                translation: translation,
                metadata: [self, #file, #function, #line]
            ) != nil {
                await archiver.removeArchivedTranslation(for: input, languagePair: languagePair)
                return await translate(
                    input,
                    with: languagePair,
                    hud: hudConfig
                )
            }

            let sanitizedTranslation = translation.withSanitizedOutput
            if translation.input.value() != translation.output {
                TranslationArchiver.addToArchive(sanitizedTranslation)
            }
            return .success(sanitizedTranslation)

        case let .failure(exception):
            guard exception.isEqual(to: .noValueExists) else {
                return .failure(exception)
            }

            let translateResult = await translator.translate(
                input,
                with: languagePair,
                hud: hudConfig,
                timeout: (.seconds(10), false)
            )

            switch translateResult {
            case let .success(translation):
                if let exception = TranslationValidator.validate(
                    translation: translation,
                    metadata: [self, #file, #function, #line]
                ) {
                    return .failure(exception)
                }

                let sanitizedTranslation = translation.withSanitizedOutput
                if translation.input.value() != translation.output {
                    await archiver.addToHostedArchive(translation)
                    TranslationArchiver.addToArchive(sanitizedTranslation)
                }
                return .success(sanitizedTranslation)

            case let .failure(exception):
                guard exception.isEqual(toAny: [.exhaustedAvailablePlatforms,
                                                .sameTranslationInputOutput]) else {
                    return .failure(exception)
                }

                let translation: Translation = .init(
                    input: input,
                    output: input.value().sanitized,
                    languagePair: languagePair
                )

                await archiver.addToHostedArchive(translation)
                TranslationArchiver.addToArchive(translation)

                return .success(translation)
            }
        }
    }
}
