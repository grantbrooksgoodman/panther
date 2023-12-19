//
//  MessageSessionService.swift
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

public struct MessageSessionService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.clientSessionService.user) private var userSession: UserSessionService

    // MARK: - Methods

    public func sendTextMessage(
        _ text: String,
        toUsers users: [User],
        inConversation conversation: Conversation?
    ) async -> Callback<Conversation, Exception> {
        guard let currentUser = userSession.currentUser else {
            return .failure(.init(
                "Current user has not been set.",
                metadata: [self, #file, #function, #line]
            ))
        }

        let users = users.filter { $0 != currentUser }

        var translations = [Translation]()

        for languageCode in users.map(\.languageCode) {
            let translateResult = await networking.services.translation.translate(
                .init(text),
                with: .init(from: currentUser.languageCode, to: languageCode)
            )

            switch translateResult {
            case let .success(translation):
                translations.append(translation)

            case let .failure(exception):
                return .failure(exception)
            }
        }

        guard translations.isWellFormed else {
            return .failure(.init(
                "Translations fail validation.",
                metadata: [self, #file, #function, #line]
            ))
        }

        let createMessageResult = await networking.services.message.createMessage(
            fromAccountID: currentUser.id,
            translations: translations,
            audioComponents: nil
        )

        switch createMessageResult {
        case let .success(message):
            if let conversation {
                return await addMessage(
                    message,
                    to: conversation
                )
            } else {
                var participantUsers = [currentUser]
                participantUsers.append(contentsOf: users)
                return await networking.services.conversation.createConversation(
                    firstMessage: message,
                    participants: participantUsers.map { Participant(userID: $0.id) }
                )
            }

        case let .failure(exception):
            return .failure(exception)
        }
    }

    // MARK: - Auxiliary

    private func addMessage(_ message: Message, to conversation: Conversation) async -> Callback<Conversation, Exception> {
        var appendedMessages = conversation.messages
        appendedMessages.append(message)

        var modifiedConversation: Conversation = .init(
            .init(key: conversation.id.key, hash: ""),
            messages: appendedMessages,
            lastModifiedDate: Date(),
            participants: conversation.participants,
            users: conversation.users
        )

        let conversationID: ConversationID = .init(
            key: modifiedConversation.id.key,
            hash: modifiedConversation.compressedHash
        )

        modifiedConversation = .init(
            conversationID,
            messages: modifiedConversation.messages,
            lastModifiedDate: modifiedConversation.lastModifiedDate,
            participants: modifiedConversation.participants,
            users: modifiedConversation.users
        )

        typealias Keys = Conversation.SerializationKeys
        let encodedConversation = modifiedConversation.encoded
        guard let encodedID = encodedConversation[Keys.id.rawValue] as? String,
              let encodedLastModifiedDate = encodedConversation[Keys.lastModifiedDate.rawValue] as? String,
              let encodedMessages = encodedConversation[Keys.messages.rawValue] as? [String] else {
            return .failure(.init(
                "Failed to unwrap encoded keys.",
                metadata: [self, #file, #function, #line]
            ))
        }

        let path = "\(networking.config.paths.conversations)/\(modifiedConversation.id.key)"

        if let exception = await networking.database.setValue(
            encodedID,
            forKey: "\(path)/\(Keys.id.rawValue)"
        ) {
            return .failure(exception)
        }

        if let exception = await networking.database.setValue(
            encodedLastModifiedDate,
            forKey: "\(path)/\(Keys.lastModifiedDate.rawValue)"
        ) {
            return .failure(exception)
        }

        if let exception = await networking.database.setValue(
            encodedMessages,
            forKey: "\(path)/\(Keys.messages.rawValue)"
        ) {
            return .failure(exception)
        }

        return .success(modifiedConversation)
    }
}
