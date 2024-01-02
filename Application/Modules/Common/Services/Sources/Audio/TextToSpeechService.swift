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

/* 3rd-party */
import Redux

public struct TextToSpeechService {
    // MARK: - Type Aliases

    private typealias FileNames = AudioService.FileNames

    // MARK: - Dependencies

    @Dependency(\.commonServices.audio) private var audioService: AudioService
    @Dependency(\.avSpeechSynthesizer) private var avSpeechSynthesizer: AVSpeechSynthesizer
    @Dependency(\.coreKit.gcd) private var coreGCD: CoreKit.GCD
    @Dependency(\.fileManager) private var fileManager: FileManager

    // MARK: - Read to File

    public func readToFile(text: String, languageCode: String) async -> Callback<URL, Exception> {
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

    // MARK: - Capabilities

    public func isTextToSpeechSupported(for languageCode: String) -> Bool {
        AVSpeechSynthesisVoice
            .speechVoices()
            .contains(where: { $0.language.lowercased().hasPrefix(languageCode.lowercased()) })
    }

    // MARK: - Auxiliary

    private func convertToM4A(file url: URL, languageCode: String) async -> Callback<URL, Exception> {
        let commonParams = ["FileURLString": url.absoluteString]

        let fileName = "\(languageCode)-\(FileNames.outputM4A)"
        let outputURL = fileManager.documentsDirectoryURL.appending(path: fileName)

        let asset = AVAsset(url: url)
        let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        )

        guard let exportSession else {
            return .failure(.init(
                "Failed to create export session.",
                extraParams: commonParams,
                metadata: [self, #file, #function, #line]
            ))
        }

        if fileManager.fileExists(atPath: fileManager.pathToFileInDocuments(named: fileName)) {
            do {
                try fileManager.removeItem(at: outputURL)
            } catch {
                let exception = Exception(error, metadata: [self, #file, #function, #line])
                return .failure(exception.appending(extraParams: commonParams))
            }
        }

        exportSession.outputFileType = AVFileType.m4a
        exportSession.outputURL = outputURL

        do {
            exportSession.metadata = try await asset.load(.metadata)
        } catch {
            let exception = Exception(error, metadata: [self, #file, #function, #line])
            return .failure(exception.appending(extraParams: commonParams))
        }

        return await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                guard let error = exportSession.error else {
                    continuation.resume(returning: .success(outputURL))
                    return
                }

                let exception = Exception(error, metadata: [self, #file, #function, #line])
                continuation.resume(returning: .failure(exception.appending(extraParams: commonParams)))
            }
        }
    }

    private func getAudioFile(from text: String, languageCode: String) async -> Callback<URL, Exception> {
        let filePath = fileManager.documentsDirectoryURL.appending(path: "\(languageCode)-\(FileNames.outputCAF)")

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = audioService.highestQualityVoice(languageCode)

        var output: AVAudioFile?

        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            return true
        }

        return await withCheckedContinuation { continuation in
            avSpeechSynthesizer.write(utterance) { buffer in
                guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
                    continuation.resume(returning: .failure(.init(
                        "Failed to typecast buffer to AVAudioPCMBuffer.",
                        metadata: [self, #file, #function, #line]
                    )))
                    return
                }

                guard pcmBuffer.frameLength == 0,
                      let output else {
                    do {
                        if output == nil {
                            output = try .init(
                                forWriting: filePath,
                                settings: pcmBuffer.format.settings,
                                commonFormat: .pcmFormatInt16,
                                interleaved: false
                            )
                        }

                        try output?.write(from: pcmBuffer)

                        guard canComplete else { return }
                        guard let output else {
                            continuation.resume(returning: .failure(.init(
                                "Failed to generate output.",
                                metadata: [self, #file, #function, #line]
                            )))
                            return
                        }

                        coreGCD.after(.milliseconds(500)) {
                            continuation.resume(returning: .success(output.url))
                        }
                    } catch {
                        guard canComplete else { return }
                        continuation.resume(returning: .failure(.init(error, metadata: [self, #file, #function, #line])))
                    }

                    return
                }

                guard canComplete else { return }
                coreGCD.after(.milliseconds(500)) {
                    continuation.resume(returning: .success(output.url))
                }
            }
        }
    }
}
