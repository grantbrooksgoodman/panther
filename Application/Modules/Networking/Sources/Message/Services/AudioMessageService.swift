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

public struct AudioMessageService {
    // MARK: - Dependencies

    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Get Audio Component

    public func getAudioComponent(for message: Message) async -> Callback<Message, Exception> {
        switch cachedAudioMessageReference(for: message) {
        case let .success(audioMessageReference):
            return .success(appendAudioComponent(audioMessageReference, to: message))

        case .failure:
            let downloadAudioMessageReferenceResult = await downloadAudioMessageReference(for: message)

            switch downloadAudioMessageReferenceResult {
            case let .success(audioMessageReference):
                return .success(appendAudioComponent(audioMessageReference, to: message))

            case let .failure(exception):
                return .failure(exception.appending(extraParams: ["MessageID": message.id]))
            }
        }
    }

    // MARK: - Delete Input Audio Component

    public func deleteInputAudioComponent(for messageID: String) async -> Exception? {
        if let exception = await networking.storage.deleteItem(
            at: "\(NetworkPath.audioMessageInputs.rawValue)/\(messageID).\(MediaFileExtension.audio(.m4a).rawValue)"
        ) {
            guard !exception.isEqual(to: .Networking.Storage.storageItemDoesNotExist) else { return nil }
            return exception
        }

        return nil
    }

    // MARK: - Upload Audio Components

    public func uploadAudioComponents(
        _ audioComponents: [AudioMessageReference],
        for message: Message
    ) async -> Exception? {
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

            let preRecordedInputExistsResult = await preRecordedInputExists(for: audioFile)

            switch preRecordedInputExistsResult {
            case let .success(preRecordedInputExists):
                guard !preRecordedInputExists else {
                    lastUploadedInput = audioFile
                    return nil
                }

                if let exception = await upload(audioFile: audioFile, to: NetworkPath.audioMessageInputs.rawValue) {
                    return exception
                }

                lastUploadedInput = audioFile
                return nil

            case let .failure(exception):
                return exception
            }
        }

        for audioComponent in audioComponents {
            if let exception = await uploadInput(audioComponent.original) {
                return exception
            }

            guard !audioComponent.translation.languagePair.isIdempotent else { continue }

            let preRecordedOutputExistsResult = await preRecordedOutputExists(for: audioComponent.translation)

            switch preRecordedOutputExistsResult {
            case let .success(preRecordedOutputExists):
                guard !preRecordedOutputExists else { continue }

                if let exception = await upload(
                    audioFile: audioComponent.translated,
                    to: audioComponent.translatedDirectoryPath
                ) {
                    return exception
                }

            case let .failure(exception):
                return exception
            }
        }

        return nil
    }

    // MARK: - Auxiliary

    private func appendAudioComponent(
        _ audioComponent: AudioMessageReference,
        to message: Message
    ) -> Message {
        var audioComponents = message.audioComponents ?? []
        audioComponents.append(audioComponent)

        let modifiedMessage: Message = .init(
            message.id,
            fromAccountID: message.fromAccountID,
            contentType: .media(.audio(.m4a)),
            richContent: .audio(audioComponents),
            translationReferences: message.translationReferences,
            translations: message.translations,
            readReceipts: message.readReceipts,
            sentDate: message.sentDate
        )

        return modifiedMessage
    }

    private func cachedAudioMessageReference(for message: Message) -> Callback<AudioMessageReference, Exception> {
        let commonParams = ["MessageID": message.id]

        guard let localAudioFilePath = message.localAudioFilePath else {
            return .failure(.init(
                "Message does not have an audio component.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        guard let inputFile = AudioFile(localAudioFilePath.inputFilePathURL),
              let outputFile = AudioFile(localAudioFilePath.outputFilePathURL) else {
            return .failure(.init(
                "Audio message reference has no local copy.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        guard let translation = message.translation else {
            return .failure(.init(
                "Message has no translation.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        return .success(.init(
            translation: translation,
            original: inputFile,
            translated: outputFile,
            translatedDirectoryPath: localAudioFilePath.outputDirectoryPathString
        ))
    }

    private func downloadAudioMessageReference(for message: Message) async -> Callback<AudioMessageReference, Exception> {
        let commonParams = ["MessageID": message.id]

        guard let localAudioFilePath = message.localAudioFilePath else {
            return .failure(.init(
                "Message does not have an audio component.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        let sourceFileURL = message.isFromCurrentUser ? localAudioFilePath.inputFilePathURL : localAudioFilePath.outputFilePathURL
        let destinationFileURL = message.isFromCurrentUser ? localAudioFilePath.outputFilePathURL : localAudioFilePath.inputFilePathURL

        if let exception = await networking.storage.downloadItem(
            at: message.isFromCurrentUser ? localAudioFilePath.inputFilePathString : localAudioFilePath.outputFilePathString,
            to: sourceFileURL
        ) {
            return .failure(exception.appending(extraParams: commonParams))
        }

        let dataFromURLResult = Data.fromURL(sourceFileURL)

        switch dataFromURLResult {
        case let .success(data):
            if let exception = fileManager.createFile(
                atPath: destinationFileURL,
                data: data
            ) {
                return .failure(exception.appending(extraParams: commonParams))
            }

        case let .failure(exception):
            return .failure(exception.appending(extraParams: commonParams))
        }

        guard let inputFile = AudioFile(localAudioFilePath.inputFilePathURL),
              let outputFile = AudioFile(localAudioFilePath.outputFilePathURL),
              let translation = message.translation else {
            return .failure(.init(
                "Failed to generate audio files or message has no translation.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        return .success(.init(
            translation: translation,
            original: inputFile,
            translated: outputFile,
            translatedDirectoryPath: localAudioFilePath.outputDirectoryPathString
        ))
    }

    private func preRecordedInputExists(for audioFile: AudioFile) async -> Callback<Bool, Exception> {
        await networking.storage.itemExists(at: "\(NetworkPath.audioMessageInputs.rawValue)/\(audioFile.name).\(audioFile.fileExtension.rawValue)")
    }

    private func preRecordedOutputExists(for translation: Translation) async -> Callback<Bool, Exception> {
        let outputDirectoryPath = "\(NetworkPath.audioTranslations.rawValue)/\(translation.reference.hostingKey)"
        let outputFileName = "\(translation.languagePair.to)-\(AudioService.FileNames.outputM4A)"
        return await networking.storage.itemExists(at: "\(outputDirectoryPath)/\(outputFileName)")
    }

    private func upload(audioFile: AudioFile, to path: String) async -> Exception? {
        let fullPath = "\(path)/\(audioFile.name).\(audioFile.fileExtension.rawValue)"
        let dataFromURLResult = Data.fromURL(audioFile.url)

        switch dataFromURLResult {
        case let .success(data):
            return await networking.storage.upload(
                data,
                metadata: .init(
                    fullPath,
                    contentType: audioFile.fileExtension.contentTypeString
                )
            )

        case let .failure(exception):
            return exception
        }
    }
}
