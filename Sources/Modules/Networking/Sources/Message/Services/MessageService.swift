//
//  MessageService.swift
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

struct MessageService {
    // MARK: - Dependencies

    @Dependency(\.timestampDateFormatter) private var dateFormatter: DateFormatter
    @Dependency(\.fileManager.documentsDirectoryURL) private var documentsDirectoryURL: URL
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Properties

    let audio: AudioMessageService
    let legacy: LegacyMessageService
    let media: MediaMessageService

    // MARK: - Init

    init(
        audio: AudioMessageService,
        legacy: LegacyMessageService,
        media: MediaMessageService
    ) {
        self.audio = audio
        self.media = media
        self.legacy = legacy
    }

    // MARK: - Message Creation

    func createMessage(
        fromAccountID: String,
        richContent: RichMessageContent?,
        translations: [Translation]?
    ) async -> Callback<Message, Exception> {
        guard !fromAccountID.isBangQualifiedEmpty,
              !(richContent == nil && translations == nil),
              translations?.isWellFormed ?? true else {
            return .failure(.init(
                "Passed arguments fail validation.",
                metadata: .init(sender: self)
            ))
        }

        guard let id = networking.database.generateKey(for: NetworkPath.messages.rawValue) else {
            return .failure(.init(
                "Failed to generate key for new message.",
                metadata: .init(sender: self)
            ))
        }

        let sentDate = Date.now

        var contentType: HostedContentType = .text
        if richContent?.audioComponents != nil {
            contentType = .audio(.m4a)
        } else if let mediaFileID = richContent?.mediaComponent?.encodedHash.shortened,
                  let mediaFileExtension = richContent?.mediaComponent?.fileExtension {
            contentType = .media(id: mediaFileID, extension: mediaFileExtension)
        }

        var mockMessage: Message = .init(
            id,
            fromAccountID: fromAccountID,
            contentType: contentType,
            richContent: richContent,
            translationReferences: translations?.map(\.reference),
            translations: translations,
            readReceipts: nil,
            sentDate: sentDate
        )

        if let exception = await networking.database.updateChildValues(
            forKey: "\(NetworkPath.messages.rawValue)/\(id)",
            with: mockMessage.encoded.filter { $0.key != Message.SerializationKeys.id.rawValue }
        ) {
            return .failure(exception)
        }

        switch mockMessage.contentType {
        case .audio:
            guard let audioComponents = mockMessage.audioComponents else {
                return .failure(.init(
                    "Failed to find audio components for audio message creation.",
                    metadata: .init(sender: self)
                ))
            }

            if let exception = await audio.uploadAudioComponents(audioComponents, for: mockMessage) {
                return .failure(exception)
            }

            // NIT: Can have uploadAudioComponents modify the message.
            mockMessage = mockMessage.replacingRichContent(.audio(
                audioComponents.reduce(into: [AudioMessageReference]()) { partialResult, audioComponent in
                    let inputFileExtension = audioComponent.original.fileExtension.rawValue
                    let outputFileExtension = audioComponent.translated.fileExtension.rawValue

                    let inputFilePath = "\(NetworkPath.audioMessageInputs.rawValue)/\(mockMessage.id).\(inputFileExtension)"
                    let outputFilePath = "\(audioComponent.translatedDirectoryPath)/\(audioComponent.translated.name).\(outputFileExtension)"

                    partialResult.append(
                        audioComponent.replacingAudioFiles(
                            newInputFileName: mockMessage.id,
                            newInputFileURL: documentsDirectoryURL.appending(path: inputFilePath),
                            newOutputFileURL: documentsDirectoryURL.appending(path: outputFilePath)
                        )
                    )
                }
            ))

            return .success(mockMessage)

        case .media:
            guard let mediaComponent = richContent?.mediaComponent else {
                return .failure(.init(
                    "Failed to find media component for media message creation.",
                    metadata: .init(sender: self)
                ))
            }

            let mediaFileID = mediaComponent.encodedHash.shortened
            if let exception = await media.uploadMediaComponent(mediaComponent, for: mockMessage) {
                return .failure(exception)
            }

            // NIT: Can have uploadMediaComponent modify the message.
            mockMessage = mockMessage.replacingRichContent(.media(.init(
                "\(NetworkPath.media.rawValue)/\(mediaFileID).\(mediaComponent.fileExtension.rawValue)",
                name: mediaFileID,
                fileExtension: mediaComponent.fileExtension
            )))

            return .success(mockMessage)

        case .text:
            return .success(mockMessage)
        }
    }

    // MARK: - Retrieval by ID

    func getMessage(id: String) async -> Callback<Message, Exception> {
        let userInfo = ["MessageID": id]

        guard !id.isBangQualifiedEmpty else {
            let exception = Exception("No ID provided.", metadata: .init(sender: self))
            return .failure(exception.appending(userInfo: userInfo))
        }

        let getValuesResult = await networking.database.getValues(at: "\(NetworkPath.messages.rawValue)/\(id)")

        switch getValuesResult {
        case let .success(values):
            guard var data = values as? [String: Any] else {
                let exception: Exception = .Networking.typecastFailed(
                    "dictionary",
                    metadata: .init(sender: self)
                )
                return .failure(exception.appending(userInfo: userInfo))
            }

            data["id"] = id
            let decodeResult = await Message.decode(from: data)

            switch decodeResult {
            case let .success(message):
                return .success(message)

            case let .failure(exception):
                return .failure(exception.appending(userInfo: userInfo))
            }

        case let .failure(exception):
            return .failure(exception.appending(userInfo: userInfo))
        }
    }

    func getMessages(ids: [String]) async -> Callback<[Message], Exception> {
        let userInfo = ["MessageIDs": ids]

        guard !ids.isBangQualifiedEmpty else {
            let exception = Exception("No IDs provided.", metadata: .init(sender: self))
            return .failure(exception.appending(userInfo: userInfo))
        }

        var messages = [Message]()

        for id in ids {
            let getMessageResult = await getMessage(id: id)

            switch getMessageResult {
            case let .success(message):
                messages.append(message)

            case let .failure(exception):
                return .failure(exception.appending(userInfo: userInfo))
            }
        }

        guard !messages.isEmpty,
              messages.count == ids.count else {
            return .failure(.init(
                "Mismatched ratio returned.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo))
        }

        return .success(messages)
    }

    // MARK: - Deletion

    // TODO: Rewrite with Message as the argument for greater efficiency.
    func deleteMessage(
        id messageID: String,
        in conversation: Conversation? = nil,
        updateConversationHash: Bool = true
    ) async -> Exception? {
        func deleteMessage() async -> Exception? {
            var exceptions = [Exception]()

            if let exception = await networking.messageService.audio.deleteInputAudioComponent(for: messageID) {
                exceptions.append(exception)
            }

            if let exception = await networking.messageService.media.deleteMediaComponent(for: messageID),
               !exception.isEqual(to: .Networking.Storage.storageItemDoesNotExist) {
                exceptions.append(exception)
            }

            if let exception = await networking.database.setValue(
                NSNull(),
                forKey: "\(NetworkPath.messages.rawValue)/\(messageID)"
            ) {
                exceptions.append(exception)
            }

            return exceptions.compiledException
        }

        guard let conversation else {
            return await deleteMessage()
        }

        if let exception = await deleteMessage() {
            return exception
        }

        let path = "\(NetworkPath.conversations.rawValue)/\(conversation.id.key)/\(Conversation.SerializationKeys.messages.rawValue)"
        let getValuesResult = await networking.database.getValues(at: path)

        switch getValuesResult {
        case let .success(values):
            guard var array = values as? [String] else {
                return .Networking.typecastFailed("array", metadata: .init(sender: self))
            }

            array.removeAll(where: { $0 == messageID })
            array = array.unique

            if let exception = await networking.database.setValue(array, forKey: path) {
                return exception
            }

            guard updateConversationHash else { return nil }

            let updateValueResult = await conversation.updateValue(
                conversation.metadata.copyWith(
                    lastModifiedDate: .now
                ),
                forKey: .metadata
            )

            switch updateValueResult {
            case .success:
                return nil

            case let .failure(exception):
                return exception
            }

        case let .failure(exception):
            return exception
        }
    }

    // TODO: Rewrite with Message as the argument for greater efficiency.
    func deleteMessages(
        ids messageIDs: [String],
        in conversation: Conversation? = nil,
        updateConversationHash: Bool = true,
        failureStrategy: BatchFailureStrategy = .returnOnFailure
    ) async -> Exception? {
        var exceptions = [Exception]()

        for messageID in messageIDs {
            if let exception = await deleteMessage(
                id: messageID,
                in: conversation,
                updateConversationHash: updateConversationHash
            ) {
                guard failureStrategy == .returnOnFailure else {
                    exceptions.append(exception)
                    continue
                }

                return exception
            }
        }

        return exceptions.compiledException
    }
}

private extension AudioMessageReference {
    func replacingAudioFiles(
        newInputFileName: String,
        newInputFileURL: URL,
        newOutputFileURL: URL
    ) -> AudioMessageReference {
        .init(
            translation: translation,
            original: .init(
                newInputFileURL,
                name: newInputFileName,
                fileExtension: original.fileExtension,
                contentDuration: original.duration
            ),
            translated: .init(
                newOutputFileURL,
                name: translated.name,
                fileExtension: translated.fileExtension,
                contentDuration: translated.duration
            ),
            translatedDirectoryPath: translatedDirectoryPath
        )
    }
}

private extension Message {
    func replacingRichContent(_ richContent: RichMessageContent?) -> Message {
        .init(
            id,
            fromAccountID: fromAccountID,
            contentType: contentType,
            richContent: richContent,
            translationReferences: translationReferences,
            translations: translations,
            readReceipts: readReceipts,
            sentDate: sentDate
        )
    }
}
