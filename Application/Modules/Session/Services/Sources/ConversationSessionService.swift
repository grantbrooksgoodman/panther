//
//  ConversationSessionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public struct ConversationSessionService {
    // MARK: - Dependencies

    @Dependency(\.standardDateFormatter) private var dateFormatter: DateFormatter
    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.clientSessionService.user) private var userSession: UserSessionService

    // MARK: - Add Messages

    public func addMessages(_ messages: [Message], to conversation: Conversation) async -> Callback<Conversation, Exception> {
        guard !messages.isEmpty else {
            return .failure(.init(
                "No messages provided.",
                metadata: [self, #file, #function, #line]
            ))
        }

        var appendedMessages = conversation.messages
        appendedMessages.append(contentsOf: messages)

        switch await conversation.updateValue(appendedMessages, forKey: .messages) {
        case let .success(conversation):
            return await conversation.updateValue(dateFormatter.string(from: Date()), forKey: .lastModifiedDate)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    // MARK: - Update Messages / Last Modified Date

    public func updateConversation(_ conversation: Conversation) async -> Callback<Conversation, Exception> {
        let conversationKeyPath = "\(networking.config.paths.conversations)/\(conversation.id.key)"

        Logger.log(
            "Updating conversation with ID \(conversation.id.key).",
            domain: .conversation,
            metadata: [self, #file, #function, #line]
        )

        func setLastModifiedDate() async -> Callback<Conversation, Exception> {
            let lastModifiedDateKeyPath = conversationKeyPath + "/\(Conversation.SerializationKey.lastModifiedDate.rawValue)"
            let getValuesResult = await networking.database.getValues(at: lastModifiedDateKeyPath)

            switch getValuesResult {
            case let .success(values):
                guard let string = values as? String else {
                    return .failure(.init(
                        "Failed to typecast values to string.",
                        metadata: [self, #file, #function, #line]
                    ))
                }

                guard let conversation = conversation.modifyKey(.lastModifiedDate, withValue: string) else {
                    return .failure(.typeMismatch(
                        key: Conversation.SerializationKey.lastModifiedDate.rawValue,
                        [self, #file, #function, #line]
                    ))
                }

                return .success(conversation)

            case let .failure(exception):
                return .failure(exception)
            }
        }

        let messagesKeyPath = conversationKeyPath + "/\(Conversation.SerializationKey.messages.rawValue)"
        let getValuesResult = await networking.database.getValues(at: messagesKeyPath)

        switch getValuesResult {
        case let .success(values):
            guard let array = values as? [String] else {
                return .failure(.init(
                    "Failed to typecast values to array.",
                    metadata: [self, #file, #function, #line]
                ))
            }

            let currentMessageIDs = conversation.messages.map(\.id)
            let filteredMessageIDs = array.filter { !currentMessageIDs.contains($0) }

            guard !filteredMessageIDs.isEmpty else {
                return await setLastModifiedDate()
            }

            let getMessagesResult = await networking.services.message.getMessages(ids: filteredMessageIDs)

            switch getMessagesResult {
            case let .success(messages):
                let updatedMessages = (conversation.messages + messages).sorted(by: { $0.sentDate < $1.sentDate })
                guard let modified = conversation.modifyKey(.messages, withValue: updatedMessages) else {
                    return .failure(.typeMismatch(key: Conversation.SerializationKeys.messages, [self, #file, #function, #line]))
                }

                return .success(modified)

            case let .failure(exception):
                return .failure(exception)
            }

        case let .failure(exception):
            return .failure(exception)
        }
    }

    // MARK: - Deletion

    public func deleteConversation(_ conversation: Conversation) async -> Exception? {
        guard conversation.participants
            .filter({ $0.userIDKey != userSession.currentUser?.id.key })
            .allSatisfy(\.hasDeletedConversation) else {
            @Persistent(.currentUserID) var currentUserID: UserID?
            guard let currentUserID else {
                return .init("No current user ID.", metadata: [self, #file, #function, #line])
            }

            return await hideConversation(conversation, forUser: currentUserID.key)
        }

        if let exception = await removeConversationFromUsers(
            userIDKeys: conversation.participants.map(\.userIDKey),
            conversationIDKey: conversation.id.key
        ) {
            return exception
        }

        if let exception = await networking.services.message.deleteMessages(
            conversation.messages,
            in: conversation,
            updateConversationHash: false
        ) {
            return exception
        }

        let path = networking.config.paths.conversations
        if let exception = await networking.database.setValue(
            NSNull(),
            forKey: "\(path)/\(conversation.id.key)"
        ) {
            return exception
        }

        // TODO: Investigate the BAD_ACCESS crash here.
//        networking.services.conversation.archive.removeValue(idKey: conversation.id.key)
//        conversation.participants.map(\.userIDKey).forEach { networking.services.user.archive.removeValue(idKey: $0) }
        
        return nil
    }

    private func hideConversation(_ conversation: Conversation, forUser userIDKey: String) async -> Exception? {
        guard let currentParticipant = conversation.participants.first(where: { $0.userIDKey == userIDKey }) else {
            return .init(
                "This conversation does not contain the specified participant.",
                extraParams: ["UserIDKey": userIDKey],
                metadata: [self, #file, #function, #line]
            )
        }
        
        var newParticipants = conversation.participants.filter { $0.userIDKey != userIDKey }
        let newParticipant: Participant = .init(
            userIDKey: currentParticipant.userIDKey,
            hasDeletedConversation: true,
            isTyping: currentParticipant.isTyping
        )

        newParticipants.append(newParticipant)
        newParticipants = newParticipants.unique
        let encodedParticipants = newParticipants.map(\.encoded)

        let path = networking.config.paths.conversations
        if let exception = await networking.database.setValue(
            encodedParticipants,
            forKey: "\(path)/\(conversation.id.key)/\(Conversation.SerializationKeys.participants.rawValue)"
        ) {
            return exception
        }

        let updateValueResult = await conversation.updateValue(dateFormatter.string(from: Date()), forKey: .lastModifiedDate)

        switch updateValueResult {
        case .success:
            return nil

        case let .failure(exception):
            return exception
        }
    }

    private func removeConversationFromUsers(userIDKeys: [String], conversationIDKey: String) async -> Exception? {
        func removeConversationFromUser(userIDKey: String, conversationIDKey: String) async -> Exception? {
            let commonParams = ["UserIDKey": userIDKey, "ConversationIDKey": conversationIDKey]

            guard !userIDKey.isBangQualifiedEmpty,
                  !conversationIDKey.isBangQualifiedEmpty else {
                let exception = Exception("Passed arguments fail validation.", metadata: [self, #file, #function, #line])
                return exception.appending(extraParams: commonParams)
            }

            let getConversationIDStringsResult = await networking.services.conversation.getConversationIDStrings(for: userIDKey)

            switch getConversationIDStringsResult {
            case var .success(conversationIDStrings):
                conversationIDStrings.removeAll(where: { $0.hasPrefix(conversationIDKey) })
                conversationIDStrings = conversationIDStrings.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : conversationIDStrings

                let path = networking.config.paths.users
                if let exception = await networking.database.setValue(
                    conversationIDStrings,
                    forKey: "\(path)/\(userIDKey)/\(User.SerializationKeys.conversations.rawValue)"
                ) {
                    return exception.appending(extraParams: commonParams)
                }

            case let .failure(exception):
                return exception.appending(extraParams: commonParams)
            }

            return nil
        }

        for userIDKey in userIDKeys {
            if let exception = await removeConversationFromUser(
                userIDKey: userIDKey,
                conversationIDKey: conversationIDKey
            ) {
                return exception
            }
        }

        return nil
    }
}
