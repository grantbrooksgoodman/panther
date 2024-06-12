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

        translate(
            text: text,
            toLanguages: Array(half)
        ) { filePath, exception in
            completion(filePath, exception)
        }
    }

    public static func translate(
        text: String,
        toLanguages: [String],
        completion: @escaping (
            _ filePath: String?,
            _ exception: Exception?
        ) -> Void
    ) {
        @Dependency(\.translatorService) var translator: TranslatorService

        var resolvedTranslations = [String: String]()

        let dispatchGroup = DispatchGroup()

        Logger.openStream(metadata: [self, #file, #function, #line])

        for (index, languageCode) in toLanguages.enumerated() {
            dispatchGroup.enter()

            translator.getTranslations(
                for: [.init(text)],
                languagePair: .init(from: "en", to: languageCode),
                timeout: (.seconds(60), true)
            ) { translations, exception in
                dispatchGroup.leave()

                guard let translations,
                      !translations.isEmpty else {
                    completion(nil, exception ?? .init(metadata: [self, #file, #function, #line]))
                    return
                }

                Logger.logToStream(
                    "Translated item \(index + 1) of \(toLanguages.count).",
                    line: #line
                )

                resolvedTranslations[languageCode] = translations[0].output
            }
        }

        dispatchGroup.notify(queue: .main) {
            Logger.closeStream(
                message: "All strings should be translated; complete.",
                onLine: #line
            )

            let hash = text.hash
            let hashCharacters = String(hash).components
            let filePath = self.createPLIST(from: resolvedTranslations, fileName: hashCharacters[0 ... hashCharacters.count / 4].joined())

            guard let path = filePath else {
                completion(nil, .init("Failed to generate PLIST.", metadata: [self, #file, #function, #line]))
                return
            }

            completion(path, nil)
        }
    }
}
