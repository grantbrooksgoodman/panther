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
import Translator

public enum PLISTGenerator {
    // MARK: - PLIST Generation

    public static func createPLIST(
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

    public static func translate(
        text: String,
        completion: @escaping (Callback<String, Exception>) -> Void
    ) {
        Task {
            completion(
                await translate(
                    text: text,
                    toLanguages: .init(RuntimeStorage.languageCodeDictionary!.keys)
                )
            )
        }
    }

    public static func translate(
        text: String,
        toLanguages: [String]
    ) async -> Callback<String, Exception> {
        @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities
        @Dependency(\.translationService) var translator: TranslationService

        coreUtilities.clearCaches([.localTranslationArchive])
        var resolvedTranslations = [String: String]()

        Logger.openStream(sender: self)

        for (index, languageCode) in toLanguages.enumerated() {
            let translateResult = await translator.translate(
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
}
