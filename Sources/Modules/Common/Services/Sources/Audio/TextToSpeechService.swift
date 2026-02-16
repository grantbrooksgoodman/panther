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
    @Dependency(\.fileManager) private var fileManager: FileManager

    // MARK: - Read to File

    func readToFile(
        text: String,
        languageCode: String
    ) async -> Callback<URL, Exception> {
        guard isTextToSpeechSupported(for: languageCode) else {
            return .failure(.init(
                "Text to speech is not supported for the specified language code.",
                userInfo: ["LanguageCode": languageCode],
                metadata: .init(sender: self)
            ))
        }

        let getAudioFileResult = await getAudioFile(
            from: text,
            languageCode: languageCode
        )

        switch getAudioFileResult {
        case let .success(url):
            return await convertToM4A(
                file: url,
                languageCode: languageCode
            )

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

        if let cachedValue = _TextToSpeechServiceCache.cachedVoicesForLanguageCodes?[languageCode] {
            return cachedValue
        }

        if let voiceForLanguageCode = AVSpeechSynthesisVoice
            .speechVoices()
            .filter({ $0.language.lowercased().hasPrefix(languageCode.lowercased()) })
            .first(where: { satisfiesConstraints($0) }) ?? .init(language: languageCode) {
            var cachedVoicesForLanguageCodes = _TextToSpeechServiceCache.cachedVoicesForLanguageCodes ?? [:]
            cachedVoicesForLanguageCodes[languageCode] = voiceForLanguageCode
            _TextToSpeechServiceCache.cachedVoicesForLanguageCodes = cachedVoicesForLanguageCodes

            return voiceForLanguageCode
        }

        return nil
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

    private func convertToM4A(
        file url: URL,
        languageCode: String
    ) async -> Callback<URL, Exception> {
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

        if fileManager.fileExists(
            atPath: fileManager.pathToFileInDocuments(named: fileName)
        ) {
            do {
                try fileManager.removeItem(at: outputURL)
            } catch {
                return .failure(
                    .init(
                        error,
                        metadata: .init(sender: self)
                    ).appending(userInfo: userInfo)
                )
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
                continuation.resume(returning: .failure(
                    .timedOut(
                        metadata: .init(sender: self)
                    ).appending(userInfo: userInfo))
                )
            }

            exportSession.exportAsynchronously {
                timeout.cancel()
                guard let error = exportSession.error else {
                    return continuation.resume(returning: .success(outputURL))
                }

                continuation.resume(returning: .failure(
                    .init(
                        error,
                        metadata: .init(sender: self)
                    ).appending(userInfo: userInfo)
                ))
            }
        }
    }

    private func getAudioFile(
        from text: String,
        languageCode: String
    ) async -> Callback<URL, Exception> {
        await TextToSpeechWriteGate.shared.run {
            let filePath = fileManager.documentsDirectoryURL.appending(
                path: "\(languageCode)-\(FileNames.outputCAF)"
            )

            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = highestQualityVoice(
                languageCode,
                mustIncludeAudioFileSettings: true
            )

            var output: AVAudioFile?
            var timeout: Timeout?

            var didComplete = false
            var canComplete: Bool {
                guard !didComplete else { return false }
                didComplete = true
                return true
            }

            return await withCheckedContinuation { continuation in
                timeout = Timeout(after: .seconds(10)) {
                    guard canComplete else { return }
                    continuation.resume(returning: .failure(.timedOut(
                        metadata: .init(sender: self)
                    )))
                }

                avSpeechSynthesizer.write(utterance) { buffer in
                    guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
                        guard canComplete else { return }
                        timeout?.cancel()

                        return continuation.resume(returning: .failure(.init(
                            "Failed to typecast buffer to AVAudioPCMBuffer.",
                            metadata: .init(sender: self)
                        )))
                    }

                    do {
                        if output == nil {
                            output = try AVAudioFile(
                                forWriting: filePath,
                                settings: pcmBuffer.format.settings,
                                commonFormat: .pcmFormatFloat32,
                                interleaved: false
                            )
                        }

                        if pcmBuffer.frameLength == 0 {
                            guard canComplete else { return }
                            timeout?.cancel()

                            guard let output else {
                                return continuation.resume(returning: .failure(.init(
                                    "Failed to generate output.",
                                    metadata: .init(sender: self)
                                )))
                            }

                            return continuation.resume(returning: .success(output.url))
                        }

                        try output?.write(from: pcmBuffer)
                    } catch {
                        guard canComplete else { return }
                        timeout?.cancel()

                        continuation.resume(returning: .failure(.init(
                            error,
                            metadata: .init(sender: self)
                        )))
                    }
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
        case voicesForLanguageCodes
    }

    // MARK: - Properties

    // swiftlint:disable:next identifier_name
    @Cached(CacheKey.textToSpeechSupportForLanguageCodes) fileprivate static var cachedTextToSpeechSupportForLanguageCodes: [String: Bool]?
    @Cached(CacheKey.voicesForLanguageCodes) fileprivate static var cachedVoicesForLanguageCodes: [String: AVSpeechSynthesisVoice]?

    // MARK: - Clear Cache

    fileprivate static func clearCache() {
        cachedTextToSpeechSupportForLanguageCodes = nil
        cachedVoicesForLanguageCodes = nil
    }
}

private actor TextToSpeechWriteGate {
    // MARK: - Properties

    static let shared = TextToSpeechWriteGate()

    private var isRunning = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    // MARK: - Run

    func run<T>(_ work: () async -> T) async -> T {
        await acquire()
        defer { release() }
        return await work()
    }

    // MARK: - Auxiliary

    private func acquire() async {
        guard isRunning else { return isRunning = true }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waiters.append(continuation)
        }
    }

    private func release() {
        guard !waiters.isEmpty else { return isRunning = false }
        waiters.removeFirst().resume()
    }
}

extension Timeout: @unchecked @retroactive Sendable {}
