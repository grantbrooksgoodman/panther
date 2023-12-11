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
            return await setAudioComponent(audioMessageReference, for: message)

        case .failure:
            let downloadAudioMessageReferenceResult = await downloadAudioMessageReference(for: message)

            switch downloadAudioMessageReferenceResult {
            case let .success(audioMessageReference):
                return await setAudioComponent(audioMessageReference, for: message)

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
            duration: audioComponent.input.duration
        )

        let translation = message.translation
        let path = "audioMessages/\(translation.languagePair.asString())/\(translation.serialized.key)"

        let audioMessageReference: AudioMessageReference = .init(
            path,
            original: modifiedInputFile,
            translated: audioComponent.output
        )

        func uploadInput() async -> Callback<Message, Exception> {
            if let exception = await upload(audioFile: modifiedInputFile, to: path) {
                return .failure(exception.appending(extraParams: commonParams))
            } else {
                return await setAudioComponent(audioMessageReference, for: message)
            }
        }

        guard translation.languagePair.from != translation.languagePair.to else {
            return await uploadInput()
        }

        let preRecordedOutputExistsResult = await preRecordedOutputExists(for: translation)

        switch preRecordedOutputExistsResult {
        case let .success(preRecordedOutputExists):
            if preRecordedOutputExists {
                return await uploadInput()
            } else {
                if let exception = await upload(audioMessageReference: audioMessageReference) {
                    return .failure(exception.appending(extraParams: commonParams))
                }

                return await setAudioComponent(audioMessageReference, for: message)
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

        guard let inputFile = AudioFile(localAudioFilePath.inputPathURL),
              let outputFile = AudioFile(localAudioFilePath.outputPathURL) else {
            return .failure(.init(
                "Audio message reference has no local copy.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        return .success(.init(
            localAudioFilePath.directoryPathString,
            original: inputFile,
            translated: outputFile
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
            at: localAudioFilePath.inputPathString,
            to: localAudioFilePath.inputPathURL
        ) {
            return .failure(exception.appending(extraParams: commonParams))
        }

        if let exception = await networking.storage.downloadItem(
            at: localAudioFilePath.outputPathString,
            to: localAudioFilePath.outputPathURL
        ) {
            return .failure(exception.appending(extraParams: commonParams))
        }

        guard let inputFile = AudioFile(localAudioFilePath.inputPathURL),
              let outputFile = AudioFile(localAudioFilePath.outputPathURL) else {
            return .failure(.init(
                "Failed to generate audio files.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        return .success(.init(
            localAudioFilePath.directoryPathString,
            original: inputFile,
            translated: outputFile
        ))
    }

    private func preRecordedOutputExists(for translation: Translation) async -> Callback<Bool, Exception> {
        let outputDirectoryPath = "audioMessages/\(translation.languagePair.asString())/\(translation.serialized.key)/"
        let outputFileName = AudioService.FileNames.outputM4A
        return await networking.storage.itemExists(at: "\(outputDirectoryPath)\(outputFileName)")
    }

    // MARK: - Deletion

    public func deleteInputAudioComponent(for message: Message) async -> Exception? {
        guard let localAudioFilePath = message.localAudioFilePath else {
            return .init(
                "Message does not have an audio component.",
                extraParams: ["MessageID": message.id],
                metadata: [self, #file, #function, #line]
            )
        }

        return await networking.storage.deleteItem(at: localAudioFilePath.inputPathString)
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

    private func upload(audioMessageReference: AudioMessageReference) async -> Exception? {
        if let exception = await upload(
            audioFile: audioMessageReference.original,
            to: audioMessageReference.directoryPath
        ) {
            return exception
        }

        if let exception = await upload(
            audioFile: audioMessageReference.translated,
            to: audioMessageReference.directoryPath
        ) {
            return exception
        }

        return nil
    }

    // MARK: - Auxiliary

    private func setAudioComponent(
        _ audioComponent: AudioMessageReference,
        for message: Message
    ) async -> Callback<Message, Exception> {
        let modifiedMessage: Message = .init(
            message.id,
            fromAccountID: message.fromAccountID,
            hasAudioComponent: true,
            audioComponent: audioComponent,
            languagePair: message.languagePair,
            translation: message.translation,
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
