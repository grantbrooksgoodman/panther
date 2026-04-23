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
    // MARK: - Types

    struct PostProcessingConfiguration {
        /* MARK: Properties */

        fileprivate let capitalizationLengthThreshold: Int?
        fileprivate let sentinelReplacements: [String: String]?
        fileprivate let strippingCharacterSet: CharacterSet?

        /* MARK: Init */

        init(
            capitalizationLengthThreshold: Int? = nil,
            sentinelReplacements: [String: String]? = nil,
            strippingCharacterSet: CharacterSet? = nil
        ) {
            assert(
                capitalizationLengthThreshold != nil ||
                    sentinelReplacements != nil ||
                    strippingCharacterSet != nil,
                "\(Self.self) – At least one non-nil value must be provided to init"
            )

            self.capitalizationLengthThreshold = capitalizationLengthThreshold
            self.sentinelReplacements = sentinelReplacements
            self.strippingCharacterSet = strippingCharacterSet
        }
    }

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
        text: String,
        postProcessingConfig: PostProcessingConfiguration? = nil,
        useEnhancedTranslation: Bool = false,
        completion: @escaping @Sendable (Callback<String, Exception>) -> Void
    ) {
        Task {
            await completion(
                translate(
                    text: text,
                    toLanguages: .init(RuntimeStorage.languageCodeDictionary!.keys),
                    postProcessingConfig: postProcessingConfig,
                    useEnhancedTranslation: useEnhancedTranslation
                )
            )
        }
    }

    // MARK: - Auxiliary

    private static func createPLIST(
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

    private static func postProcess(
        _ string: String,
        with configuration: PostProcessingConfiguration?
    ) -> String {
        guard let configuration else { return string.sanitized.trimmingBorderedWhitespace }
        let whitespaceSeparatedComponents = string
            .sanitized
            .trimmingBorderedWhitespace
            .components(separatedBy: .whitespaces)

        var stringComponents = [String]()
        if let lengthThreshold = configuration.capitalizationLengthThreshold {
            for (index, component) in whitespaceSeparatedComponents.enumerated() {
                guard component.count > lengthThreshold ||
                    index == 0 ||
                    index == whitespaceSeparatedComponents.count - 1 else {
                    stringComponents.append(component)
                    continue
                }

                stringComponents.append(component.firstUppercase)
            }
        } else {
            stringComponents = whitespaceSeparatedComponents
        }

        if let characterSet = configuration.strippingCharacterSet {
            stringComponents = stringComponents.map {
                $0.trimmingCharacters(in: characterSet)
            }
        }

        if let sentinelReplacements = configuration.sentinelReplacements,
           !sentinelReplacements.isEmpty {
            for (key, value) in sentinelReplacements {
                stringComponents = stringComponents.map {
                    $0.replacingOccurrences(
                        of: key,
                        with: value
                    )
                }
            }
        }

        return stringComponents.joined(separator: " ")
    }

    private static func translate(
        text: String,
        toLanguages: [String],
        postProcessingConfig: PostProcessingConfiguration?,
        useEnhancedTranslation: Bool
    ) async -> Callback<String, Exception> {
        @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities

        Logger.openStream(sender: self)
        coreUtilities.clearCaches([.localTranslationArchive])

        let resolvedTranslations: [String: String] = await withTaskGroup(
            of: (String, String).self,
            returning: [String: String].self
        ) { taskGroup in
            var nextIndex = 0
            var translationOutputsByLanguageCode = [String: String]()

            func enqueueNextTask() {
                guard nextIndex < toLanguages.count else { return }
                let languageCode = toLanguages[nextIndex]
                nextIndex += 1

                taskGroup.addTask {
                    await _translate(
                        text: text,
                        languageCode: languageCode,
                        postProcessingConfig: postProcessingConfig,
                        useEnhancedTranslation: useEnhancedTranslation
                    )
                }
            }

            let maxConcurrentOperations = min(
                20,
                toLanguages.count
            )

            for _ in 0 ..< maxConcurrentOperations { enqueueNextTask() }

            var totalCompleted = 0
            while let (languageCode, translation) = await taskGroup.next() {
                totalCompleted += 1
                Logger.log(
                    "Translated item \(totalCompleted) of \(toLanguages.count).",
                    sender: self
                )

                translationOutputsByLanguageCode[languageCode] = translation
                enqueueNextTask()
            }

            return translationOutputsByLanguageCode
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

    private static func _translate(
        text: String,
        languageCode: String,
        postProcessingConfig: PostProcessingConfiguration?,
        useEnhancedTranslation: Bool
    ) async -> (String, String) {
        @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities
        @Dependency(\.networking.hostedTranslation) var hostedTranslator: HostedTranslationDelegate
        @Dependency(\.translationService) var translator: TranslationService

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
            return (
                languageCode,
                postProcess(
                    translation.output,
                    with: postProcessingConfig
                )
            )

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
                    postProcessingConfig: postProcessingConfig,
                    useEnhancedTranslation: false
                )
            }

            Logger.log(exception)
            return (
                languageCode,
                postProcess(
                    text,
                    with: postProcessingConfig
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
}
