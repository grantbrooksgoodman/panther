//
//  AudioMessageService.swift
//  Panther
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

struct AudioMessageService {
    // MARK: - Dependencies

    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Get Audio Component

    func getAudioComponent(
        messageID: String,
        isFromCurrentUser: Bool,
        localAudioFilePath: LocalAudioFilePath,
        translation: Translation
    ) async throws(Exception) -> AudioMessageReference {
        do {
            return try cachedAudioMessageReference(
                for: localAudioFilePath,
                translation: translation
            )
        } catch {
            return try await downloadAudioMessageReference(
                messageID: messageID,
                isFromCurrentUser: isFromCurrentUser,
                localAudioFilePath: localAudioFilePath,
                translation: translation
            )
        }
    }

    // MARK: - Delete Input Audio Component

    // TODO: This is inefficient. Rewrite with Message as the argument.
    func deleteInputAudioComponent(
        for messageID: String
    ) async throws(Exception) {
        do {
            try await networking.storage.deleteItem(
                at: [
                    NetworkPath.audioMessageInputs.rawValue,
                    "\(messageID).\(MediaFileExtension.audio(.m4a).rawValue)",
                ].joined(separator: "/")
            )
        } catch {
            guard !error.isEqual(
                to: .Networking.Storage.storageItemDoesNotExist
            ) else { return }
            throw error
        }
    }

    // MARK: - Upload Audio Components

    // TODO: Can be parallelized with some rethinking.
    func uploadAudioComponents(
        _ audioComponents: [AudioMessageReference],
        for message: Message
    ) async throws(Exception) {
        var didMoveInputFile = false
        var lastUploadedInput: AudioFile?

        func uploadInput(
            _ audioFile: AudioFile
        ) async throws(Exception) {
            let audioFile: AudioFile = .init(
                audioFile.url,
                name: message.id,
                fileExtension: audioFile.fileExtension,
                contentDuration: audioFile.contentDuration ?? .init()
            )

            if let lastUploadedInput,
               lastUploadedInput == audioFile {
                return
            }

            guard await !preRecordedInputExists(for: audioFile) else {
                return lastUploadedInput = audioFile
            }

            try await upload(
                audioFile: audioFile,
                to: NetworkPath.audioMessageInputs.rawValue
            )

            lastUploadedInput = audioFile
        }

        for audioComponent in audioComponents {
            func moveOutputFile() {
                // swiftlint:disable:next line_length
                let outputFilePath = "\(audioComponent.translatedDirectoryPath)/\(audioComponent.translated.name).\(audioComponent.translated.fileExtension.rawValue)"
                do {
                    try fileManager.move(
                        fileAt: audioComponent.translated.url,
                        toPath: fileManager.documentsDirectoryURL.appending(
                            path: outputFilePath
                        )
                    )
                } catch {
                    Logger.log(error)
                }

                do {
                    try fileManager.removeItem(
                        at: fileManager.documentsDirectoryURL.appending(
                            path: "\(audioComponent.translated.name).\(AudioFileExtension.caf.rawValue)"
                        )
                    )
                } catch {
                    Logger.log(.init(
                        error,
                        metadata: .init(sender: self)
                    ))
                }
            }

            try await uploadInput(audioComponent.original)

            if !didMoveInputFile {
                let inputFilePath = "\(NetworkPath.audioMessageInputs.rawValue)/\(message.id).\(audioComponent.original.fileExtension.rawValue)"
                do {
                    try fileManager.move(
                        fileAt: audioComponent.original.url,
                        toPath: fileManager.documentsDirectoryURL.appending(path: inputFilePath)
                    )
                    didMoveInputFile = true
                } catch {
                    Logger.log(error)
                }
            }

            guard !audioComponent.translation.languagePair.isIdempotent else { continue }
            defer { moveOutputFile() }
            guard await !preRecordedOutputExists(for: audioComponent.translation) else { continue }

            try await upload(
                audioFile: audioComponent.translated,
                to: audioComponent.translatedDirectoryPath
            )
        }
    }

    // MARK: - Auxiliary

    func preRecordedOutputExists(for translation: Translation) async -> Bool {
        let outputDirectoryPath = "\(NetworkPath.audioTranslations.rawValue)/\(translation.reference.hostingKey)"
        let outputFileName = "\(translation.languagePair.to)-\(AudioService.FileNames.outputM4A)"
        return await (try? networking.storage.itemExists(
            at: "\(outputDirectoryPath)/\(outputFileName)"
        )) == true
    }

    private func cachedAudioMessageReference(
        for localAudioFilePath: LocalAudioFilePath,
        translation: Translation
    ) throws(Exception) -> AudioMessageReference {
        guard let inputFile = AudioFile(localAudioFilePath.inputFilePathURL),
              let outputFile = AudioFile(localAudioFilePath.outputFilePathURL) else {
            throw Exception(
                "Audio message reference has no local copy.",
                isReportable: false,
                metadata: .init(sender: self)
            )
        }

        return .init(
            translation: translation,
            original: inputFile,
            translated: outputFile,
            translatedDirectoryPath: localAudioFilePath.outputDirectoryPathString
        )
    }

    private func downloadAudioMessageReference(
        messageID: String,
        isFromCurrentUser: Bool,
        localAudioFilePath: LocalAudioFilePath,
        translation: Translation
    ) async throws(Exception) -> AudioMessageReference {
        let userInfo = ["MessageID": messageID]

        let sourceFileURL = isFromCurrentUser ? localAudioFilePath.inputFilePathURL : localAudioFilePath.outputFilePathURL
        let destinationFileURL = isFromCurrentUser ? localAudioFilePath.outputFilePathURL : localAudioFilePath.inputFilePathURL

        do {
            try await networking.storage.downloadItem(
                at: isFromCurrentUser ? localAudioFilePath.inputFilePathString : localAudioFilePath.outputFilePathString,
                to: sourceFileURL
            )
        } catch {
            throw error.appending(userInfo: userInfo)
        }

        do {
            try fileManager.createFile(
                atPath: destinationFileURL,
                data: Data.fromURL(sourceFileURL)
            )
        } catch {
            throw error.appending(userInfo: userInfo)
        }

        guard let inputFile = AudioFile(localAudioFilePath.inputFilePathURL),
              let outputFile = AudioFile(localAudioFilePath.outputFilePathURL) else {
            throw Exception(
                "Failed to generate audio files.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        return .init(
            translation: translation,
            original: inputFile,
            translated: outputFile,
            translatedDirectoryPath: localAudioFilePath.outputDirectoryPathString
        )
    }

    private func preRecordedInputExists(for audioFile: AudioFile) async -> Bool {
        await (try? networking.storage.itemExists(
            at: "\(NetworkPath.audioMessageInputs.rawValue)/\(audioFile.name).\(audioFile.fileExtension.rawValue)"
        )) == true
    }

    private func upload(
        audioFile: AudioFile,
        to path: String
    ) async throws(Exception) {
        try await networking.storage.upload(
            Data.fromURL(audioFile.url),
            metadata: .init(
                [
                    path,
                    "\(audioFile.name).\(audioFile.fileExtension.rawValue)",
                ].joined(separator: "/"),
                contentType: audioFile.fileExtension.contentTypeString
            )
        )
    }
}
