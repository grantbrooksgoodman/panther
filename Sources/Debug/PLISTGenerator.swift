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
        forKey key: String? = nil,
        sourceLanguageCode: String = "en",
        plistName: String = "LocalizedStrings",
        processingConfig: Localization.ProcessingConfiguration? = nil,
        postProcess: ((String) -> String)? = nil,
        enhancementContext: String? = nil
    ) async throws(Exception) -> String {
        try await Localization.createPLIST(
            translating: text,
            withKey: key,
            sourceLanguageCode: sourceLanguageCode,
            plistConfig: .init(name: plistName),
            processingConfig: processingConfig,
            postProcessingTransformation: postProcess
        ) { languageCode throws(Exception) in
            try await _translate(
                text: text,
                sourceLanguageCode: sourceLanguageCode,
                targetLanguageCode: languageCode,
                enhancementContext: enhancementContext
            )
        }
    }

    static func translate(
        _ text: String,
        forKey key: String? = nil,
        plistName: String = "LocalizedStrings",
        processingConfig: Localization.ProcessingConfiguration? = nil,
        postProcess: ((String) -> String)? = nil,
        enhancementContext: String? = nil,
        completion: @escaping @Sendable (Callback<String, Exception>) -> Void
    ) {
        let postProcess = LockIsolated<((String) -> String)?>(postProcess)
        Task {
            do throws(Exception) {
                try await completion(.success(
                    translate(
                        text,
                        forKey: key,
                        plistName: plistName,
                        processingConfig: processingConfig,
                        postProcess: postProcess.wrappedValue,
                        enhancementContext: enhancementContext
                    )
                ))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Auxiliary

    private static func _translate(
        text: String,
        sourceLanguageCode: String,
        targetLanguageCode: String,
        enhancementContext: String?
    ) async throws(Exception) -> Translation {
        @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities
        @Dependency(\.networking.hostedTranslation) var hostedTranslator: HostedTranslationDelegate
        @Dependency(\.translationArchiverDelegate) var translationArchiverDelegate: TranslationArchiverDelegate
        @Dependency(\.translationService) var translator: TranslationService

        translationArchiverDelegate.clearArchive()
        let useEnhancedTranslation = enhancementContext != nil
        if useEnhancedTranslation {
            coreUtilities.clearCaches([.Networking.gemini])
        }

        do {
            return enhancementContext == nil ? try await translator.translate(
                .init(text),
                languagePair: .init(
                    from: sourceLanguageCode,
                    to: targetLanguageCode
                ),
                hud: nil,
                timeout: (.seconds(60), true)
            ) : try await hostedTranslator.translate(
                .init(text),
                with: .init(
                    from: sourceLanguageCode,
                    to: targetLanguageCode
                ),
                enhance: .init(
                    additionalContext: "\(enhancementContext!)\n\(additionalContext)"
                )
            )
        } catch {
            if useEnhancedTranslation {
                Logger.log(.init(
                    "Enhanced translation failed – trying without enhancement.",
                    isReportable: false,
                    userInfo: ["ExceptionDescriptor": error.descriptor],
                    metadata: .init(sender: self)
                ))

                return try await _translate(
                    text: text,
                    sourceLanguageCode: sourceLanguageCode,
                    targetLanguageCode: targetLanguageCode,
                    enhancementContext: enhancementContext
                )
            }

            Logger.log(error)
            return .init(
                input: .init(text),
                output: text,
                languagePair: .init(
                    from: sourceLanguageCode,
                    to: targetLanguageCode
                )
            )
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
        return pathComponents[0 ... pathComponents.count - 2]
            .joined(separator: "/")
    }
}
