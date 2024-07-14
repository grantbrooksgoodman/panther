//
//  MessageService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture
import Translator

public struct MessageService {
    // MARK: - Dependencies

    @Dependency(\.standardDateFormatter) private var dateFormatter: DateFormatter
    @Dependency(\.networking) private var networking: Networking

    // MARK: - Properties

    public let audio: AudioMessageService
    public let legacy: LegacyMessageService
    public let media: MediaMessageService

    // MARK: - Init

    public init(
        audio: AudioMessageService,
        legacy: LegacyMessageService,
        media: MediaMessageService
    ) {
        self.audio = audio
        self.media = media
        self.legacy = legacy
    }

    // MARK: - Message Creation

    public func createMessage(
        fromAccountID: String,
        richContent: RichMessageContent?,
        translations: [Translation]?
    ) async -> Callback<Message, Exception> {
        guard !fromAccountID.isBangQualifiedEmpty,
              !(richContent == nil && translations == nil),
              translations?.isWellFormed ?? true else {
            return .failure(.init(
                "Passed arguments fail validation.",
                metadata: [self, #file, #function, #line]
            ))
        }

        guard let id = networking.database.generateKey(for: networking.config.paths.messages) else {
            return .failure(.init(
                "Failed to generate key for new message.",
                metadata: [self, #file, #function, #line]
            ))
        }

        let sentDate = Date()

        var contentType: ContentType = .text
        if richContent?.audioComponents != nil {
            contentType = .audio
        } else if richContent?.mediaComponent != nil {
            contentType = .media
        }

        typealias Keys = Message.SerializationKeys
        let data: [String: Any] = [
            Keys.fromAccountID.rawValue: fromAccountID,
            Keys.contentType.rawValue: contentType.rawValue,
            Keys.translations.rawValue: translations?.map(\.reference.hostingKey).sorted() ?? .bangQualifiedEmpty,
            Keys.readDate.rawValue: String.bangQualifiedEmpty,
            Keys.sentDate.rawValue: dateFormatter.string(from: sentDate),
        ]

        let mockMessage: Message = .init(
            id,
            fromAccountID: fromAccountID,
            contentType: contentType,
            richContent: richContent,
            translations: translations,
            readDate: nil,
            sentDate: sentDate
        )

        func uploadMedia() async -> Callback<Message, Exception> {
            func uploadAudioMessageReferenceIfNeeded() async -> Callback<Message, Exception> {
                guard mockMessage.contentType == .audio,
                      let audioComponent = mockMessage.audioComponent else {
                    return .success(mockMessage)
                }

                if let exception = await audio.uploadAudioComponents([audioComponent], for: mockMessage) {
                    return .failure(exception)
                }

                return .success(mockMessage)
            }

            guard mockMessage.contentType == .media,
                  let mediaComponent = mockMessage.richContent?.mediaComponent else { return await uploadAudioMessageReferenceIfNeeded() }

            if let exception = await media.uploadMediaComponent(mediaComponent, for: mockMessage) {
                return .failure(exception)
            }

            return .success(mockMessage)
        }

        if let exception = await networking.database.updateChildValues(
            forKey: "\(networking.config.paths.messages)/\(id)",
            with: data
        ) {
            return .failure(exception)
        }

        return await uploadMedia()
    }

    // MARK: - Retrieval by ID

    public func getMessage(id: String) async -> Callback<Message, Exception> {
        let commonParams = ["MessageID": id]

        guard !id.isBangQualifiedEmpty else {
            let exception = Exception("No ID provided.", metadata: [self, #file, #function, #line])
            return .failure(exception.appending(extraParams: commonParams))
        }

        let getValuesResult = await networking.database.getValues(at: "\(networking.config.paths.messages)/\(id)")

        switch getValuesResult {
        case let .success(values):
            guard var data = values as? [String: Any] else {
                let exception: Exception = .typecastFailed("dictionary", metadata: [self, #file, #function, #line])
                return .failure(exception.appending(extraParams: commonParams))
            }

            data["id"] = id
            let decodeResult = await Message.decode(from: data)

            switch decodeResult {
            case let .success(message):
                return .success(message)

            case let .failure(exception):
                return .failure(exception.appending(extraParams: commonParams))
            }

        case let .failure(exception):
            return .failure(exception.appending(extraParams: commonParams))
        }
    }

    public func getMessages(ids: [String]) async -> Callback<[Message], Exception> {
        let commonParams = ["MessageIDs": ids]

        guard !ids.isBangQualifiedEmpty else {
            let exception = Exception("No IDs provided.", metadata: [self, #file, #function, #line])
            return .failure(exception.appending(extraParams: commonParams))
        }

        var messages = [Message]()

        for id in ids {
            let getMessageResult = await getMessage(id: id)

            switch getMessageResult {
            case let .success(message):
                messages.append(message)

            case let .failure(exception):
                return .failure(exception.appending(extraParams: commonParams))
            }
        }

        guard !messages.isEmpty,
              messages.count == ids.count else {
            return .failure(.init(
                "Mismatched ratio returned.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        return .success(messages)
    }

    // MARK: - Deletion

    public func deleteMessage(
        id messageID: String,
        in conversation: Conversation? = nil,
        updateConversationHash: Bool = true
    ) async -> Exception? {
        func deleteMessage() async -> Exception? {
            if let exception = await networking.services.message.audio.deleteInputAudioComponent(for: messageID) {
                return exception
            }

            if let exception = await networking.database.setValue(
                NSNull(),
                forKey: "\(networking.config.paths.messages)/\(messageID)"
            ) {
                return exception
            }

            return nil
        }

        guard let conversation else {
            return await deleteMessage()
        }

        if let exception = await deleteMessage() {
            return exception
        }

        let path = "\(networking.config.paths.conversations)/\(conversation.id.key)/\(Conversation.SerializationKeys.messages.rawValue)"
        let getValuesResult = await networking.database.getValues(at: path)

        switch getValuesResult {
        case let .success(values):
            guard var array = values as? [String] else {
                return .typecastFailed("array", metadata: [self, #file, #function, #line])
            }

            array.removeAll(where: { $0 == messageID })
            array = array.unique

            if let exception = await networking.database.setValue(array, forKey: path) {
                return exception
            }

            guard updateConversationHash else { return nil }

            let newMetadata: ConversationMetadata = .init(
                name: conversation.metadata.name,
                imageData: conversation.metadata.imageData,
                lastModifiedDate: Date()
            )

            let updateValueResult = await conversation.updateValue(newMetadata, forKey: .metadata)

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

    public func deleteMessages(
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
