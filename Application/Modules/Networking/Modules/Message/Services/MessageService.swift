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
import Redux
import Translator

public struct MessageService {
    // MARK: - Dependencies

    @Dependency(\.standardDateFormatter) private var dateFormatter: DateFormatter
    @Dependency(\.networking) private var networking: Networking

    // MARK: - Properties

    public let audio: AudioMessageService

    // MARK: - Init

    public init(audio: AudioMessageService) {
        self.audio = audio
    }

    // MARK: - Message Creation

    public func createMessage(
        fromAccountID: String,
        translation: Translation,
        audioComponent: (input: AudioFile, output: AudioFile)?
    ) async -> Callback<Message, Exception> {
        guard !fromAccountID.isBangQualifiedEmpty,
              TranslationValidator.validate(
                  translation: translation,
                  metadata: [self, #file, #function, #line]
              ) == nil else {
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

        typealias Keys = Message.SerializationKeys
        let data: [String: Any] = [
            Keys.fromAccountID.rawValue: fromAccountID,
            Keys.hasAudioComponent.rawValue: audioComponent == nil ? "false" : "true",
            Keys.languagePair.rawValue: translation.languagePair.asString(),
            Keys.translation.rawValue: translation.serialized.key,
            Keys.readDate.rawValue: String.bangQualifiedEmpty,
            Keys.sentDate.rawValue: dateFormatter.string(from: sentDate),
        ]

        let mockMessage: Message = .init(
            id,
            fromAccountID: fromAccountID,
            hasAudioComponent: audioComponent != nil,
            audioComponent: nil,
            languagePair: translation.languagePair,
            translation: translation,
            readDate: nil,
            sentDate: sentDate
        )

        func uploadAudioMessageReferenceIfNeeded() async -> Callback<Message, Exception> {
            guard mockMessage.hasAudioComponent,
                  let audioComponent else {
                return .success(mockMessage)
            }

            return await audio.uploadAudioComponent(for: mockMessage, audioComponent: audioComponent)
        }

        if let exception = await networking.database.updateChildValues(
            forKey: "\(networking.config.paths.messages)/\(id)",
            with: data
        ) {
            return .failure(exception)
        }

        return await uploadAudioMessageReferenceIfNeeded()
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
                let exception = Exception("Failed to typecast values to dictionary.", metadata: [self, #file, #function, #line])
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
        _ message: Message,
        in conversation: Conversation? = nil
    ) async -> Exception? {
        func deleteMessage(_ message: Message) async -> Exception? {
            if message.hasAudioComponent,
               let exception = await networking.services.message.audio.deleteInputAudioComponent(for: message) {
                return exception
            }

            if let exception = await networking.database.setValue(
                NSNull(),
                forKey: "\(networking.config.paths.messages)/\(message.id)"
            ) {
                return exception
            }

            return nil
        }

        guard let conversation else {
            return await deleteMessage(message)
        }

        if let exception = await deleteMessage(message) {
            return exception
        }

        let path = "\(networking.config.paths.conversations)/\(conversation.id.key)/\(Conversation.SerializationKeys.messages.rawValue)"
        let getValuesResult = await networking.database.getValues(at: path)

        switch getValuesResult {
        case let .success(values):
            guard var array = values as? [String] else {
                return .init("Failed to typecast values to array.", metadata: [self, #file, #function, #line])
            }

            array.removeAll(where: { $0 == message.id })
            array = array.unique

            if let exception = await networking.database.setValue(array, forKey: path) {
                return exception
            }

        case let .failure(exception):
            return exception
        }

        return nil
    }

    public func deleteMessages(
        _ messages: [Message],
        in conversation: Conversation? = nil
    ) async -> Exception? {
        for message in messages {
            if let exception = await deleteMessage(message, in: conversation) {
                return exception
            }
        }

        return nil
    }
}
