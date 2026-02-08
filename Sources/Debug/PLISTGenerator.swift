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
    // MARK: - PLIST Generation

    static func createPLIST(
        from dictionary: [String: Any],
        fileName: String? = nil
    ) -> String? {
        let fileManager = FileManager.default

        let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let path = documentDirectory.appending("/\(fileName ?? String(Int.random(in: 1 ... 1_000_000))).plist")

        guard !fileManager.fileExists(atPath: path) else {
            Logger.log(.init(
                "File already exists.",
                userInfo: ["FilePath": path],
                metadata: .init(sender: self)
            ))
            return nil
        }

        NSData(data: Data()).write(toFile: path, atomically: true)
        NSDictionary(dictionary: dictionary).write(toFile: path, atomically: true)
        return path
    }

    // MARK: - Text Translation

    static func translate(
        text: String,
        useEnhancedTranslation: Bool = false,
        completion: @escaping (Callback<String, Exception>) -> Void
    ) {
        Task {
            completion(
                await translate(
                    text: text,
                    toLanguages: .init(RuntimeStorage.languageCodeDictionary!.keys),
                    useEnhancedTranslation: useEnhancedTranslation
                )
            )
        }
    }

    static func translate(
        text: String,
        toLanguages: [String],
        useEnhancedTranslation: Bool
    ) async -> Callback<String, Exception> {
        @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities
        @Dependency(\.networking.hostedTranslation) var hostedTranslator: HostedTranslationDelegate
        @Dependency(\.translationService) var translator: TranslationService

        coreUtilities.clearCaches([.localTranslationArchive])
        var resolvedTranslations = [String: String]()

        Logger.openStream(sender: self)

        for (index, languageCode) in toLanguages.enumerated() {
            if useEnhancedTranslation { coreUtilities.clearCaches([.Networking.gemini]) }
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
                Logger.logToStream(
                    "Translated item \(index + 1) of \(toLanguages.count).",
                    line: #line
                )

                resolvedTranslations[languageCode] = translation
                    .output
                    .sanitized
                    .trimmingBorderedWhitespace

            case let .failure(exception):
                Logger.logToStream(
                    "Translated(?) item \(index + 1) of \(toLanguages.count).",
                    line: #line
                )

                Logger.log(exception)
                resolvedTranslations[languageCode] = text
                    .sanitized
                    .trimmingBorderedWhitespace
            }
        }

        Logger.closeStream(
            message: "All strings should be translated; complete.",
            onLine: #line
        )

        guard let filePath = createPLIST(
            from: resolvedTranslations,
            fileName: Date.now.formattedShortString.encodedHash
        ) else {
            return .failure(.init(
                "Failed to generate PLIST.",
                metadata: .init(sender: self)
            ))
        }

        return .success(filePath)
    }

    // MARK: - Auxiliary

    private static var additionalContext: String {
        @Dependency(\.build) var build: Build

        let dynamicContextSuffix = [
            build.finalName,
            build.codeName,
        ].first { !$0.isBlank }.map { " for an app called \($0)." } ?? "."

        return """
        You are translating text as part of standard, user-facing system dialogs\(dynamicContextSuffix)
        Be sure to use an appropriate, respectful, and neutral tone.
        Ensure consistency in pronoun usage and grammatical correctness.
        Use infinitive forms for user actions where it makes sense (e.g., use 'Cerrar' in place of 'Cierra' for Spanish).
        """
    }
}
