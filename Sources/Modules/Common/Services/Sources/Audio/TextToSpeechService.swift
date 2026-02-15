//
//  TextToSpeechService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import AVFoundation
import Foundation

/* Proprietary */
import AppSubsystem

struct TextToSpeechService {
    // MARK: - Type Aliases

    private typealias FileNames = AudioService.FileNames

    // MARK: - Dependencies

    @Dependency(\.avSpeechSynthesizer) private var avSpeechSynthesizer: AVSpeechSynthesizer
    @Dependency(\.coreKit.gcd) private var coreGCD: CoreKit.GCD
    @Dependency(\.fileManager) private var fileManager: FileManager

    // MARK: - Read to File

    func readToFile(text: String, languageCode: String) async -> Callback<URL, Exception> {
        guard isTextToSpeechSupported(for: languageCode) else {
            return .failure(.init(
                "Text to speech is not supported for the specified language code.",
                userInfo: ["LanguageCode": languageCode],
                metadata: .init(sender: self)
            ))
        }

        let getAudioFileResult = await getAudioFile(from: text, languageCode: languageCode)

        switch getAudioFileResult {
        case let .success(url):
            let convertToM4AResult = await convertToM4A(file: url, languageCode: languageCode)

            switch convertToM4AResult {
            case let .success(url):
                return .success(url)

            case let .failure(exception):
                return .failure(exception)
            }

        case let .failure(exception):
            return .failure(exception)
        }
    }

    // MARK: - Highest Quality Voice

    func highestQualityVoice(
        _ languageCode: String,
        mustIncludeAudioFileSettings: Bool = false
    ) -> AVSpeechSynthesisVoice? {
        func satisfiesConstraints(_ voice: AVSpeechSynthesisVoice) -> Bool {
            if mustIncludeAudioFileSettings {
                guard voice.quality == .enhanced || voice.quality == .premium,
                      !voice.audioFileSettings.isEmpty else { return false }
            } else {
                guard voice.quality == .enhanced || voice.quality == .premium else { return false }
            }

            return true
        }

        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix(languageCode.lowercased()) }
            .first(where: { satisfiesConstraints($0) }) ?? .init(language: languageCode)
    }

    // MARK: - Capabilities

    func isTextToSpeechSupported(for languageCode: String) -> Bool {
        if let cachedValue = _TextToSpeechServiceCache.cachedTextToSpeechSupportForLanguageCodes?[languageCode] {
            return cachedValue
        }

        let isTextToSpeechSupported = AVSpeechSynthesisVoice
            .speechVoices()
            .contains(where: { $0.language.lowercased().hasPrefix(languageCode.lowercased()) })

        // swiftlint:disable:next identifier_name
        var cachedTextToSpeechSupportForLanguageCodes = _TextToSpeechServiceCache.cachedTextToSpeechSupportForLanguageCodes ?? [:]
        cachedTextToSpeechSupportForLanguageCodes[languageCode] = isTextToSpeechSupported
        _TextToSpeechServiceCache.cachedTextToSpeechSupportForLanguageCodes = cachedTextToSpeechSupportForLanguageCodes
        return isTextToSpeechSupported
    }

    // MARK: - Auxiliary

    private func convertToM4A(file url: URL, languageCode: String) async -> Callback<URL, Exception> {
        let userInfo = ["FileURLString": url.absoluteString]

        let fileName = "\(languageCode)-\(FileNames.outputM4A)"
        let outputURL = fileManager.documentsDirectoryURL.appending(path: fileName)

        let asset = AVAsset(url: url)
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            return .failure(.init(
                "Failed to create export session.",
                userInfo: userInfo,
                metadata: .init(sender: self)
            ))
        }

        if fileManager.fileExists(atPath: fileManager.pathToFileInDocuments(named: fileName)) {
            do {
                try fileManager.removeItem(at: outputURL)
            } catch {
                let exception = Exception(error, metadata: .init(sender: self))
                return .failure(exception.appending(userInfo: userInfo))
            }
        }

        exportSession.outputFileType = AVFileType.m4a
        exportSession.outputURL = outputURL

        do {
            exportSession.metadata = try await asset.load(.metadata)
        } catch {
            let exception = Exception(error, metadata: .init(sender: self))
            return .failure(exception.appending(userInfo: userInfo))
        }

        return await withCheckedContinuation { continuation in
            let timeout = Timeout(after: .seconds(10)) {
                continuation.resume(returning: .failure(.timedOut(
                    metadata: .init(sender: self)
                ).appending(userInfo: userInfo)))
            }

            exportSession.exportAsynchronously {
                timeout.cancel()
                guard let error = exportSession.error else {
                    continuation.resume(returning: .success(outputURL))
                    return
                }

                let exception = Exception(error, metadata: .init(sender: self))
                continuation.resume(returning: .failure(exception.appending(userInfo: userInfo)))
            }
        }
    }

    private func getAudioFile(from text: String, languageCode: String) async -> Callback<URL, Exception> {
        let filePath = fileManager.documentsDirectoryURL.appending(path: "\(languageCode)-\(FileNames.outputCAF)")

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = highestQualityVoice(languageCode, mustIncludeAudioFileSettings: true)

        var output: AVAudioFile?

        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            return true
        }

        return await withCheckedContinuation { continuation in
            let timeout = Timeout(after: .seconds(10)) {
                guard canComplete else { return }
                continuation.resume(returning: .failure(.timedOut(
                    metadata: .init(sender: self)
                )))
            }

            avSpeechSynthesizer.write(utterance) { buffer in
                guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
                    continuation.resume(returning: .failure(.init(
                        "Failed to typecast buffer to AVAudioPCMBuffer.",
                        metadata: .init(sender: self)
                    )))
                    return
                }

                guard pcmBuffer.frameLength <= 1,
                      let output else {
                    do {
                        if output == nil {
                            output = try .init(
                                forWriting: filePath,
                                settings: pcmBuffer.format.settings,
                                commonFormat: .pcmFormatFloat32,
                                interleaved: false
                            )
                        }

                        try output?.write(from: pcmBuffer)

                        guard canComplete else { return }
                        guard let output else {
                            continuation.resume(returning: .failure(.init(
                                "Failed to generate output.",
                                metadata: .init(sender: self)
                            )))
                            return
                        }

                        coreGCD.after(.milliseconds(500)) {
                            timeout.cancel()
                            continuation.resume(returning: .success(output.url))
                        }
                    } catch {
                        guard canComplete else { return }
                        continuation.resume(returning: .failure(.init(error, metadata: .init(sender: self))))
                    }

                    return
                }

                guard canComplete else { return }
                coreGCD.after(.milliseconds(500)) {
                    timeout.cancel()
                    continuation.resume(returning: .success(output.url))
                }
            }
        }
    }
}

enum TextToSpeechServiceCache {
    static func clearCache() {
        _TextToSpeechServiceCache.clearCache()
    }
}

private enum _TextToSpeechServiceCache {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case textToSpeechSupportForLanguageCodes
    }

    // MARK: - Properties

    // swiftlint:disable:next identifier_name
    @Cached(CacheKey.textToSpeechSupportForLanguageCodes) fileprivate static var cachedTextToSpeechSupportForLanguageCodes: [String: Bool]?

    // MARK: - Clear Cache

    fileprivate static func clearCache() {
        cachedTextToSpeechSupportForLanguageCodes = nil
    }
}

extension Timeout: @unchecked @retroactive Sendable {}
