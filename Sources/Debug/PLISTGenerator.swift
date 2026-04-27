//
//  PLISTGenerator.swift
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

enum PLISTGenerator {
    // MARK: - Properties

    private static var additionalContext: String {
        @Dependency(\.build) var build: Build

        let dynamicContextSuffix = [
            build.finalName,
            build.codeName,
        ].first { !$0.isBlank }.map { " for an app called \($0)." } ?? "."

        return """
        You are translating text as part of standard, user-facing system dialogs\(dynamicContextSuffix)
        Be sure to use an appropriate, respectful, and neutral tone.
        Ensure consistency in pronoun usage and grammatical correctness in the context of system dialogs.
        Use infinitive forms for user actions where it makes sense (e.g., use 'cerrar' in place of 'cierra' for Spanish).
        """
    }

    // MARK: - Methods

    static func translate(
        _ text: String,
        forKey key: String,
        plistName: String = "LocalizedStrings",
        postProcessingConfig: Localization.PostProcessingConfiguration? = nil,
        useEnhancedTranslation: Bool = false
    ) async -> Callback<String, Exception> {
        await Localization.createPLIST(
            translating: text,
            plistConfig: .init(
                key: key,
                name: plistName
            ),
            postProcessingConfig: postProcessingConfig
        ) { languageCode in
            await _translate(
                text: text,
                languageCode: languageCode,
                useEnhancedTranslation: useEnhancedTranslation
            )
        }
    }

    static func translate(
        _ text: String,
        forKey key: String,
        plistName: String = "LocalizedStrings",
        postProcessingConfig: Localization.PostProcessingConfiguration? = nil,
        useEnhancedTranslation: Bool = false,
        completion: @escaping @Sendable (Callback<String, Exception>) -> Void
    ) {
        Task {
            await completion(
                translate(
                    text,
                    forKey: key,
                    plistName: plistName,
                    postProcessingConfig: postProcessingConfig,
                    useEnhancedTranslation: useEnhancedTranslation
                )
            )
        }
    }

    // MARK: - Auxiliary

    private static func _translate(
        text: String,
        languageCode: String,
        useEnhancedTranslation: Bool
    ) async -> Callback<Translation, Exception> {
        @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities
        @Dependency(\.networking.hostedTranslation) var hostedTranslator: HostedTranslationDelegate
        @Dependency(\.translationArchiverDelegate) var translationArchiverDelegate: TranslationArchiverDelegate
        @Dependency(\.translationService) var translator: TranslationService

        translationArchiverDelegate.clearArchive()
        if useEnhancedTranslation {
            coreUtilities.clearCaches([.Networking.gemini])
        }

        let translateResult = useEnhancedTranslation ? await hostedTranslator.translate(
            .init(text),
            with: .init(from: "en", to: languageCode),
            enhance: .init(additionalContext: additionalContext)
        ) : await translator.translate(
            .init(text),
            languagePair: .init(from: "en", to: languageCode),
            hud: nil,
            timeout: (.seconds(60), true)
        )

        switch translateResult {
        case let .success(translation):
            return .success(translation)

        case let .failure(exception):
            if useEnhancedTranslation {
                Logger.log(.init(
                    "Enhanced translation failed – trying without enhancement.",
                    isReportable: false,
                    userInfo: ["ExceptionDescriptor": exception.descriptor],
                    metadata: .init(sender: self)
                ))

                return await _translate(
                    text: text,
                    languageCode: languageCode,
                    useEnhancedTranslation: false
                )
            }

            Logger.log(exception)
            return .success(.init(
                input: .init(text),
                output: text,
                languagePair: .init(from: "en", to: languageCode),
            ))
        }
    }
}

extension String {
    enum Sentinel {
        static let asterism = "⁂"
        static let loopedSquare = "⌘"
    }

    var directoryPath: String {
        let pathComponents = replacingOccurrences(of: "//", with: "/")
            .components(separatedBy: "/")

        guard pathComponents.count > 1 else { return pathComponents.joined(separator: "/") }
        let directoryPath = pathComponents[0 ... pathComponents.count - 2]
            .joined(separator: "/")

        return directoryPath
    }
}
