//
//  HostedTranslationService+AKTranslationDelegate.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import AlertKit
import Translator

extension HostedTranslationService: AKTranslationDelegate {
    // swiftlint:disable:next function_parameter_count
    public func getTranslations(
        for inputs: [AlertKit.TranslationInput],
        languagePair: AlertKit.LanguagePair,
        requiresHUD: Bool?,
        using: AlertKit.PlatformName?,
        fetchFromArchive: Bool,
        completion: @escaping (
            _ translations: [AlertKit.Translation]?,
            _ errorDescriptors: [String: AlertKit.TranslationInput]?
        ) -> Void
    ) {
        let languagePairComparator: Translator.LanguagePair = .init(from: languagePair.from, to: languagePair.to)
        guard languagePairComparator.isWellFormed,
              !languagePairComparator.isIdempotent else {
            let map = inputs.map { AlertKit.Translation(
                input: $0,
                output: $0.value(),
                languagePair: languagePair
            ) }
            completion(map, nil)
            return
        }

        getTranslations(
            for: inputs.map { Translator.TranslationInput($0.original, alternate: $0.alternate) },
            languagePair: .init(from: languagePair.from, to: languagePair.to),
            hud: (requiresHUD ?? true) ? (appearsAfter: .seconds(5), isModal: true) : nil
        ) { translations, exception in
            guard let translations,
                  !translations.isEmpty else {
                let exceptionDescriptor = exception?.descriptor ?? Exception(metadata: [self, #file, #function, #line]).descriptor
                var descriptorPairs = [String: AlertKit.TranslationInput]()
                inputs.forEach { descriptorPairs[exceptionDescriptor] = AlertKit.TranslationInput($0.original, alternate: $0.alternate) }
                completion(nil, descriptorPairs)
                return
            }

            completion(
                translations.map {
                    AlertKit.Translation(
                        input: .init($0.input.original, alternate: $0.input.alternate),
                        output: $0.output,
                        languagePair: .init(from: $0.languagePair.from, to: $0.languagePair.to)
                    )
                }, nil
            )
        }
    }

    private func getTranslations(
        for inputs: [Translator.TranslationInput],
        languagePair: Translator.LanguagePair,
        hud hudConfig: (appearsAfter: Duration, isModal: Bool)? = nil,
        completion: @escaping (_ translations: [Translator.Translation]?, _ exception: Exception?) -> Void
    ) {
        Task {
            let getTranslationsResult = await getTranslations(
                for: inputs,
                languagePair: languagePair,
                hud: hudConfig
            )

            switch getTranslationsResult {
            case let .success(translations):
                await MainActor.run { completion(translations, nil) }

            case let .failure(exception):
                await MainActor.run { completion(nil, exception) }
            }
        }
    }
}
