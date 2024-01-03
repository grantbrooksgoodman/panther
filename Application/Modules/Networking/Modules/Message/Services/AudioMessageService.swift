//
//  AudioMessageService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux
import Translator

public struct AudioMessageService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: Networking

    // MARK: - Public

    public func getAudioComponent(for message: Message) async -> Callback<Message, Exception> {
        switch cachedAudioMessageReference(for: message) {
        case let .success(audioMessageReference):
            return await appendAudioComponent(audioMessageReference, to: message)

        case .failure:
            let downloadAudioMessageReferenceResult = await downloadAudioMessageReference(for: message)

            switch downloadAudioMessageReferenceResult {
            case let .success(audioMessageReference):
                return await appendAudioComponent(audioMessageReference, to: message)

            case let .failure(exception):
                return .failure(exception.appending(extraParams: ["MessageID": message.id]))
            }
        }
    }

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
                duration: audioFile.duration ?? .init()
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

                if let exception = await upload(audioFile: audioFile, to: networking.config.paths.audioMessageInputs) {
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

    // MARK: - Retrieval

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

        return .success(.init(
            translation: message.translation,
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

        if let exception = await networking.storage.downloadItem(
            at: localAudioFilePath.inputFilePathString,
            to: localAudioFilePath.inputFilePathURL
        ) {
            return .failure(exception.appending(extraParams: commonParams))
        }

        if let exception = await networking.storage.downloadItem(
            at: localAudioFilePath.outputFilePathString,
            to: localAudioFilePath.outputFilePathURL
        ) {
            return .failure(exception.appending(extraParams: commonParams))
        }

        guard let inputFile = AudioFile(localAudioFilePath.inputFilePathURL),
              let outputFile = AudioFile(localAudioFilePath.outputFilePathURL) else {
            return .failure(.init(
                "Failed to generate audio files.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        return .success(.init(
            translation: message.translation,
            original: inputFile,
            translated: outputFile,
            translatedDirectoryPath: localAudioFilePath.outputDirectoryPathString
        ))
    }

    private func preRecordedInputExists(for audioFile: AudioFile) async -> Callback<Bool, Exception> {
        await networking.storage.itemExists(at: "\(networking.config.paths.audioMessageInputs)/\(audioFile.name).\(audioFile.fileExtension.rawValue)")
    }

    private func preRecordedOutputExists(for translation: Translation) async -> Callback<Bool, Exception> {
        let outputDirectoryPath = "\(networking.config.paths.audioTranslations)/\(translation.reference.hostingKey)"
        let outputFileName = "\(translation.languagePair.to)-\(AudioService.FileNames.outputM4A)"
        return await networking.storage.itemExists(at: "\(outputDirectoryPath)/\(outputFileName)")
    }

    // MARK: - Deletion

    public func deleteInputAudioComponent(for message: Message) async -> Exception? {
        guard message.hasAudioComponent else {
            return .init(
                "Message does not have an audio component.",
                extraParams: ["MessageID": message.id],
                metadata: [self, #file, #function, #line]
            )
        }

        return await networking.storage.deleteItem(at: "\(networking.config.paths.audioMessageInputs)/\(message.id).\(AudioFileExtension.m4a.rawValue)")
    }

    // MARK: - Upload

    private func upload(audioFile: AudioFile, to path: String) async -> Exception? {
        let fullPath = "\(path)/\(audioFile.name).\(audioFile.fileExtension.rawValue)"

        do {
            let data = try Data(contentsOf: audioFile.url)
            return await networking.storage.upload(
                data,
                metadata: .init(
                    fullPath,
                    contentType: audioFile.fileExtension.contentTypeString
                )
            )
        } catch {
            return .init(error, metadata: [self, #file, #function, #line])
        }
    }

    // MARK: - Auxiliary

    private func appendAudioComponent(
        _ audioComponent: AudioMessageReference,
        to message: Message
    ) async -> Callback<Message, Exception> {
        var audioComponents = message.audioComponents ?? []
        audioComponents.append(audioComponent)

        let modifiedMessage: Message = .init(
            message.id,
            fromAccountID: message.fromAccountID,
            hasAudioComponent: true,
            audioComponents: audioComponents,
            translations: message.translations,
            readDate: message.readDate,
            sentDate: message.sentDate
        )

        return .success(modifiedMessage)
    }
}
