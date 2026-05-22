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
    func deleteInputAudioComponent(for messageID: String) async -> Exception? {
        if let exception = await networking.storage.deleteItem(
            at: "\(NetworkPath.audioMessageInputs.rawValue)/\(messageID).\(MediaFileExtension.audio(.m4a).rawValue)"
        ) {
            guard !exception.isEqual(to: .Networking.Storage.storageItemDoesNotExist) else { return nil }
            return exception
        }

        return nil
    }

    // MARK: - Upload Audio Components

    // TODO: Can be parallelized with some rethinking.
    func uploadAudioComponents(
        _ audioComponents: [AudioMessageReference],
        for message: Message
    ) async -> Exception? {
        var didMoveInputFile = false
        var lastUploadedInput: AudioFile?

        func uploadInput(_ audioFile: AudioFile) async -> Exception? {
            let audioFile: AudioFile = .init(
                audioFile.url,
                name: message.id,
                fileExtension: audioFile.fileExtension,
                contentDuration: audioFile.contentDuration ?? .init()
            )

            if let lastUploadedInput,
               lastUploadedInput == audioFile {
                return nil
            }

            guard await !preRecordedInputExists(for: audioFile) else {
                lastUploadedInput = audioFile
                return nil
            }

            if let exception = await upload(
                audioFile: audioFile,
                to: NetworkPath.audioMessageInputs.rawValue
            ) {
                return exception
            }

            lastUploadedInput = audioFile
            return nil
        }

        for audioComponent in audioComponents {
            func moveOutputFile() {
                // swiftlint:disable:next line_length
                let outputFilePath = "\(audioComponent.translatedDirectoryPath)/\(audioComponent.translated.name).\(audioComponent.translated.fileExtension.rawValue)"
                if let exception = fileManager.move(
                    fileAt: audioComponent.translated.url,
                    toPath: fileManager.documentsDirectoryURL.appending(path: outputFilePath)
                ) {
                    Logger.log(exception)
                }

                do { // swiftlint:disable:next line_length
                    try fileManager.removeItem(at: fileManager.documentsDirectoryURL.appending(path: "\(audioComponent.translated.name).\(AudioFileExtension.caf.rawValue)"))
                } catch {
                    Logger.log(.init(error, metadata: .init(sender: self)))
                }
            }

            if let exception = await uploadInput(audioComponent.original) {
                return exception
            }

            if !didMoveInputFile {
                let inputFilePath = "\(NetworkPath.audioMessageInputs.rawValue)/\(message.id).\(audioComponent.original.fileExtension.rawValue)"
                if let exception = fileManager.move(
                    fileAt: audioComponent.original.url,
                    toPath: fileManager.documentsDirectoryURL.appending(path: inputFilePath)
                ) {
                    Logger.log(exception)
                } else {
                    didMoveInputFile = true
                }
            }

            guard !audioComponent.translation.languagePair.isIdempotent else { continue }
            defer { moveOutputFile() }
            guard await !preRecordedOutputExists(for: audioComponent.translation) else { continue }

            if let exception = await upload(
                audioFile: audioComponent.translated,
                to: audioComponent.translatedDirectoryPath
            ) {
                return exception
            }
        }

        return nil
    }

    // MARK: - Auxiliary

    func preRecordedOutputExists(for translation: Translation) async -> Bool {
        let outputDirectoryPath = "\(NetworkPath.audioTranslations.rawValue)/\(translation.reference.hostingKey)"
        let outputFileName = "\(translation.languagePair.to)-\(AudioService.FileNames.outputM4A)"
        return await (try? networking.storage.itemExists(
            at: "\(outputDirectoryPath)/\(outputFileName)"
        ).get()) == true
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

        if let exception = await networking.storage.downloadItem(
            at: isFromCurrentUser ? localAudioFilePath.inputFilePathString : localAudioFilePath.outputFilePathString,
            to: sourceFileURL
        ) {
            throw exception.appending(userInfo: userInfo)
        }

        do throws(Exception) {
            if let exception = try fileManager.createFile(
                atPath: destinationFileURL,
                data: Data.fromURL(sourceFileURL)
            ) {
                throw exception.appending(userInfo: userInfo)
            }
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
        ).get()) == true
    }

    private func upload(
        audioFile: AudioFile,
        to path: String
    ) async -> Exception? {
        let fullPath = "\(path)/\(audioFile.name).\(audioFile.fileExtension.rawValue)"

        do {
            return try await networking.storage.upload(
                Data.fromURL(audioFile.url),
                metadata: .init(
                    fullPath,
                    contentType: audioFile.fileExtension.contentTypeString
                )
            )
        } catch {
            return error
        }
    }
}
