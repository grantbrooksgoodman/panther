//
//  PLISTGenerator.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture
import Translator

public enum PLISTGenerator {
    // MARK: - Properties

    public enum Half {
        case first
        case second
    }

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
                extraParams: ["FilePath": path],
                metadata: [self, #file, #function, #line]
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
        toHalf: Half,
        completion: @escaping (
            _ filePath: String?,
            _ exception: Exception?
        ) -> Void
    ) {
        let languageCodeArray = Array(RuntimeStorage.languageCodeDictionary!.keys)

        // swiftlint:disable:next line_length
        let half = toHalf == .first ? languageCodeArray.sorted(by: { $0 < $1 })[0 ... languageCodeArray.count / 2] : languageCodeArray.sorted(by: { $0 < $1 })[(languageCodeArray.count / 2) + 1 ... languageCodeArray.count - 1]

        Task {
            let translateResult = await translate(text: text, toLanguages: Array(half))

            switch translateResult {
            case let .success(filePath):
                completion(filePath, nil)

            case let .failure(exception):
                completion(nil, exception)
            }
        }
    }

    public static func translate(
        text: String,
        toLanguages: [String]
    ) async -> Callback<String, Exception> {
        @Dependency(\.translationService) var translator: TranslationService
        @Dependency(\.localTranslationArchiver) var localTranslationArchiver: LocalTranslationArchiver

        localTranslationArchiver.clearArchive()
        var resolvedTranslations = [String: String]()

        Logger.openStream(metadata: [self, #file, #function, #line])

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

                resolvedTranslations[languageCode] = translation.output

            case let .failure(exception):
                Logger.logToStream(
                    "Translated(?) item \(index + 1) of \(toLanguages.count).",
                    line: #line
                )

                Logger.log(exception)
                resolvedTranslations[languageCode] = text
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
                metadata: [self, #file, #function, #line]
            ))
        }

        return .success(filePath)
    }
}
