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

/// The service that uploads, downloads, and deletes audio message content.
struct AudioMessageService {
    // MARK: - Dependencies

    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Get Audio Component

    /// Returns the audio component for the given message, using the local copy when available and
    /// downloading it otherwise.
    ///
    /// - Parameters:
    ///   - messageID: The identifier of the message.
    ///   - isFromCurrentUser: A Boolean value that indicates whether the message was sent by the
    ///     current user.
    ///   - localAudioFilePath: The local file paths for the message's audio.
    ///   - translation: The translation associated with the audio.
    ///
    /// - Returns: The audio component.
    ///
    /// - Throws: An `Exception` if the audio cannot be resolved or downloaded.
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

    /// Deletes the input recording for the given message from remote storage.
    ///
    /// This method has no effect when no input recording exists.
    ///
    /// - Parameter messageID: The identifier of the message.
    ///
    /// - Throws: An `Exception` if deletion fails for a reason other than the item not existing.
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

    /// Uploads the input recording and translated output audio for the given message.
    ///
    /// The input and each output are uploaded concurrently, and the local files are moved into
    /// their permanent locations afterward.
    ///
    /// - Parameters:
    ///   - audioComponents: The audio components to upload.
    ///   - message: The message the audio belongs to.
    ///   - inputUploadTask: A task whose completion provides an already-in-progress input upload,
    ///     or `nil` to upload the input as part of this call.
    ///   - outputUploadTasks: Tasks whose completion provides already-in-progress output uploads,
    ///     keyed by translation hosting key. A missing entry uploads that output as part of this
    ///     call.
    ///
    /// - Throws: An `Exception` if an upload fails.
    func uploadAudioComponents(
        _ audioComponents: [AudioMessageReference],
        for message: Message,
        inputUploadTask: Task<Callback<Void, Exception>, Never>? = nil,
        outputUploadTasks: [String: Task<Callback<Void, Exception>, Never>] = [:]
    ) async throws(Exception) {
        enum UploadOperation {
            case input
            case output(AudioMessageReference)
        }

        func moveOutputFile(for audioComponent: AudioMessageReference) {
            guard audioComponent.translated.url != audioComponent.original.url else { return }

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

            let temporaryDirectoryURL = audioComponent.translated.url.deletingLastPathComponent()
            guard temporaryDirectoryURL.lastPathComponent.hasPrefix(
                AudioService.DirectoryNames.textToSpeechOutputPrefix
            ) else { return }

            do {
                try fileManager.removeItem(at: temporaryDirectoryURL)
            } catch {
                Logger.log(.init(
                    error,
                    metadata: .init(sender: self)
                ))
            }
        }

        func uploadInput() async throws(Exception) {
            guard let originalFile = audioComponents.first?.original else { return }

            if let inputUploadTask {
                try await (inputUploadTask.value).get()
            } else {
                try await uploadInputAudioComponent(
                    originalFile,
                    messageID: message.id,
                    isRetry: true
                )
            }

            let inputFilePath = "\(NetworkPath.audioMessageInputs.rawValue)/\(message.id).\(originalFile.fileExtension.rawValue)"
            do {
                try fileManager.move(
                    fileAt: originalFile.url,
                    toPath: fileManager.documentsDirectoryURL.appending(path: inputFilePath)
                )
            } catch {
                Logger.log(error)
            }
        }

        /// The placeholder convention is authoritative: for a
        /// non-idempotent pair, translated.url == original.url means a
        /// pre-recorded output exists and there is nothing to upload.
        func uploadOutput(for audioComponent: AudioMessageReference) async throws(Exception) {
            guard !audioComponent.translation.languagePair.isIdempotent,
                  audioComponent.translated.url != audioComponent.original.url else { return }
            defer { moveOutputFile(for: audioComponent) }

            // Prefer the pipelined upload the caller started
            // at synthesis time; a failure rethrows exactly where
            // the inline upload would have, keeping the outbox retry surface unchanged.
            if let outputUploadTask = outputUploadTasks[audioComponent.translation.reference.hostingKey] {
                try await (outputUploadTask.value).get()
            } else {
                try await upload(
                    audioFile: audioComponent.translated,
                    to: audioComponent.translatedDirectoryPath
                )
            }
        }

        guard !audioComponents.isEmpty else { return }
        try await ([UploadOperation.input] + audioComponents.map { .output($0) })
            .forEachConcurrently { operation throws(Exception) in
                switch operation {
                case .input: try await uploadInput()
                case let .output(audioComponent):
                    try await uploadOutput(for: audioComponent)
                }
            }
    }

    /// Uploads the input recording under the specified message ID
    /// without moving the local file; sequencing of the move is the
    /// caller's responsibility.
    func uploadInputAudioComponent(
        _ inputFile: AudioFile,
        messageID: String,
        isRetry: Bool
    ) async throws(Exception) {
        let renamedInputFile: AudioFile = .init(
            inputFile.url,
            name: messageID,
            fileExtension: inputFile.fileExtension,
            contentDuration: inputFile.contentDuration ?? .init()
        )

        // Only a retry with a reserved ID can find a pre-recorded
        // input; fresh sends upload immediately.
        if isRetry,
           await preRecordedInputExists(for: renamedInputFile) {
            return
        }

        try await upload(
            audioFile: renamedInputFile,
            to: NetworkPath.audioMessageInputs.rawValue
        )
    }

    /// Uploads the translated output for the given component without
    /// moving the local file; sequencing of the move is the caller's
    /// responsibility.
    func uploadOutputAudioComponent(
        _ audioComponent: AudioMessageReference
    ) async throws(Exception) {
        try await upload(
            audioFile: audioComponent.translated,
            to: audioComponent.translatedDirectoryPath
        )
    }

    // MARK: - Auxiliary

    /// Returns a Boolean value that indicates whether a pre-recorded translated output already
    /// exists in remote storage for the given translation.
    ///
    /// - Parameter translation: The translation to check.
    ///
    /// - Returns: `true` if a pre-recorded output exists; otherwise, `false`.
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
            fileAt: audioFile.url,
            metadata: .init(
                [
                    path,
                    "\(audioFile.name).\(audioFile.fileExtension.rawValue)",
                ].joined(separator: "/"),
                contentType: audioFile.fileExtension.contentTypeString
            ),
            timeout: .transferTimeout(forItemAt: audioFile.url)
        )
    }
}
