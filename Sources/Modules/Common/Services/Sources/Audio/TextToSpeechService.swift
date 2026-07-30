//
//  TextToSpeechService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import AVFAudio
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
    ) async throws(Exception) -> URL {
        guard isTextToSpeechSupported(for: languageCode) else {
            throw Exception(
                "Text to speech is not supported for the specified language code.",
                userInfo: ["LanguageCode": languageCode],
                metadata: .init(sender: self)
            )
        }

        return try await getAudioFile(
            from: text,
            languageCode: languageCode
        )
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

    private func getAudioFile(
        from text: String,
        languageCode: String
    ) async throws(Exception) -> URL {
        try await TextToSpeechWriteGate
            .shared
            .run { () async throws(Exception) -> URL in
                let fileName = "\(languageCode)-\(FileNames.outputM4A)"
                let filePath = fileManager.documentsDirectoryURL.appending(path: fileName)

                if fileManager.fileExists(
                    atPath: fileManager.pathToFileInDocuments(named: fileName)
                ) {
                    do {
                        try fileManager.removeItem(at: filePath)
                    } catch {
                        throw Exception(
                            error,
                            metadata: .init(sender: self)
                        ).appending(userInfo: ["FileURLString": filePath.absoluteString])
                    }
                }

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

                do {
                    return try await withCheckedThrowingContinuation { continuation in
                        timeout = Timeout(after: .seconds(10)) {
                            guard canComplete else { return }
                            continuation.resume(throwing: Exception.timedOut(
                                metadata: .init(sender: self)
                            ))
                        }

                        avSpeechSynthesizer.write(utterance) { buffer in
                            guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
                                guard canComplete else { return }
                                timeout?.cancel()

                                return continuation.resume(throwing: Exception(
                                    "Failed to typecast buffer to AVAudioPCMBuffer.",
                                    metadata: .init(sender: self)
                                ))
                            }

                            do {
                                if output == nil {
                                    output = try AVAudioFile(
                                        forWriting: filePath,
                                        settings: [
                                            AVFormatIDKey: kAudioFormatMPEG4AAC,
                                            AVSampleRateKey: pcmBuffer.format.sampleRate,
                                            AVNumberOfChannelsKey: pcmBuffer.format.channelCount,
                                            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                                        ],
                                        commonFormat: .pcmFormatFloat32,
                                        interleaved: false
                                    )
                                }

                                if pcmBuffer.frameLength == 0 {
                                    guard canComplete else { return }
                                    timeout?.cancel()

                                    guard let output else {
                                        return continuation.resume(throwing: Exception(
                                            "Failed to generate output.",
                                            metadata: .init(sender: self)
                                        ))
                                    }

                                    return continuation.resume(returning: output.url)
                                }

                                try output?.write(from: pcmBuffer)
                            } catch {
                                guard canComplete else { return }
                                timeout?.cancel()

                                continuation.resume(throwing: Exception(
                                    error,
                                    metadata: .init(sender: self)
                                ))
                            }
                        }
                    }
                } catch {
                    guard let exception = error as? Exception else {
                        throw Exception(
                            error,
                            metadata: .init(sender: self)
                        )
                    }

                    throw exception
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
    // MARK: - Properties

    // swiftlint:disable identifier_name
    private static let _cachedTextToSpeechSupportForLanguageCodes = LockIsolated<[String: Bool]?>(nil)
    private static let _cachedVoicesForLanguageCodes = LockIsolated<[String: AVSpeechSynthesisVoice]?>(nil)

    // MARK: - Computed Properties

    fileprivate static var cachedTextToSpeechSupportForLanguageCodes: [String: Bool]? {
        get { _cachedTextToSpeechSupportForLanguageCodes.wrappedValue }
        set { _cachedTextToSpeechSupportForLanguageCodes.wrappedValue = newValue }
    }

    fileprivate static var cachedVoicesForLanguageCodes: [String: AVSpeechSynthesisVoice]? {
        get { _cachedVoicesForLanguageCodes.wrappedValue }
        set { _cachedVoicesForLanguageCodes.wrappedValue = newValue }
    } // swiftlint:enable identifier_name

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

    func run<T>(
        _ work: () async throws(Exception) -> T
    ) async throws(Exception) -> T {
        await acquire()
        defer { release() }
        return try await work()
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
