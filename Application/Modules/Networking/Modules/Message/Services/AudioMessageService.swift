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

    public func getAudioComponent(for message: Message, languageCode: String) async -> Callback<Message, Exception> {
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

    public func uploadAudioComponent(
        for message: Message,
        audioComponent: (input: AudioFile, output: AudioFile)
    ) async -> Callback<Message, Exception> {
        let commonParams = ["MessageID": message.id]

        guard message.hasAudioComponent else {
            return .failure(.init(
                "Message does not have an audio component.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        let modifiedInputFile: AudioFile = .init(
            audioComponent.input.url,
            name: message.id,
            fileExtension: audioComponent.input.fileExtension,
            duration: audioComponent.input.duration ?? .init()
        )

        let audioMessageReference: AudioMessageReference = .init(
            message.translation.languagePair.to,
            original: modifiedInputFile,
            originalDirectoryPath: networking.config.paths.audioMessageInputs,
            translated: audioComponent.output,
            translatedDirectoryPath: "\(networking.config.paths.audioTranslations)/\(message.translation.model.referenceKey)"
        )

        func uploadInput() async -> Callback<Message, Exception> {
            let preRecordedInputExistsResult = await preRecordedInputExists(for: modifiedInputFile)

            switch preRecordedInputExistsResult {
            case let .success(preRecordedInputExists):
                guard !preRecordedInputExists else {
                    return await appendAudioComponent(audioMessageReference, to: message)
                }

                if let exception = await upload(audioFile: modifiedInputFile, to: networking.config.paths.audioMessageInputs) {
                    return .failure(exception.appending(extraParams: commonParams))
                } else {
                    return await appendAudioComponent(audioMessageReference, to: message)
                }

            case let .failure(exception):
                return .failure(exception.appending(extraParams: commonParams))
            }
        }

        guard !message.translation.languagePair.isIdempotent else {
            return await uploadInput()
        }

        let preRecordedOutputExistsResult = await preRecordedOutputExists(for: message.translation)

        switch preRecordedOutputExistsResult {
        case let .success(preRecordedOutputExists):
            guard !preRecordedOutputExists else {
                return await uploadInput()
            }

            let uploadInputResult = await uploadInput()

            switch uploadInputResult {
            case let .success(message):
                if let exception = await upload(
                    audioFile: audioMessageReference.translated,
                    to: audioMessageReference.translatedDirectoryPath
                ) {
                    return .failure(exception.appending(extraParams: commonParams))
                }

                return .success(message)

            case let .failure(exception):
                return .failure(exception.appending(extraParams: commonParams))
            }

        case let .failure(exception):
            return .failure(exception.appending(extraParams: commonParams))
        }
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
            message.translation.languagePair.to,
            original: inputFile,
            originalDirectoryPath: localAudioFilePath.inputDirectoryPathString,
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
            message.translation.languagePair.to,
            original: inputFile,
            originalDirectoryPath: localAudioFilePath.inputDirectoryPathString,
            translated: outputFile,
            translatedDirectoryPath: localAudioFilePath.outputDirectoryPathString
        ))
    }

    private func preRecordedInputExists(for audioFile: AudioFile) async -> Callback<Bool, Exception> {
        await networking.storage.itemExists(at: "\(networking.config.paths.audioMessageInputs)/\(audioFile.name).\(audioFile.fileExtension.rawValue)")
    }

    private func preRecordedOutputExists(for translation: Translation) async -> Callback<Bool, Exception> {
        let outputDirectoryPath = "\(networking.config.paths.audioTranslations)/\(translation.model.referenceKey)"
        let outputFileName = AudioService.FileNames.outputM4A
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

        guard !message.hasAudioComponent else { return .success(modifiedMessage) }

        if let exception = await networking.database.setValue(
            modifiedMessage.hasAudioComponent,
            forKey: "\(networking.config.paths.messages)/\(message.id)/\(Message.SerializationKeys.hasAudioComponent.rawValue)"
        ) {
            return .failure(exception.appending(extraParams: ["MessageID": message.id]))
        }

        return .success(modifiedMessage)
    }
}
