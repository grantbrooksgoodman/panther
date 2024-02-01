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

public final class ConversationSessionService {
    // MARK: - Dependencies

    @Dependency(\.standardDateFormatter) private var dateFormatter: DateFormatter
    @Dependency(\.networking) private var networking: Networking

    // MARK: - Properties

    public private(set) var currentConversation: Conversation?

    @Persistent(.currentUserID) private var currentUserID: String?

    // MARK: - Add Messages

    public func addMessages(_ messages: [Message], to conversation: Conversation) async -> Callback<Conversation, Exception> {
        guard !messages.isEmpty else {
            return .failure(.init(
                "No messages provided.",
                metadata: [self, #file, #function, #line]
            ))
        }

        var appendedMessages = conversation.messages ?? []
        appendedMessages.append(contentsOf: messages)

        switch await conversation.updateValue(appendedMessages, forKey: .messages) {
        case let .success(conversation):
            return .success(conversation)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    // MARK: - Set Current Conversation

    public func setCurrentConversation(_ currentConversation: Conversation) {
        self.currentConversation = currentConversation
    }

    // MARK: - Update Messages / Last Modified Date

    // swiftlint:disable:next function_body_length
    public func updateConversation(_ conversation: Conversation) async -> Callback<Conversation, Exception> {
        let conversationKeyPath = "\(networking.config.paths.conversations)/\(conversation.id.key)"

        Logger.log(
            "Updating conversation with ID \(conversation.id.key).",
            domain: .conversation,
            metadata: [self, #file, #function, #line]
        )

        func updateParticipants(_ conversation: Conversation) async -> Callback<Conversation, Exception> {
            func updateHash(_ conversation: Conversation) async -> Callback<Conversation, Exception> {
                let hashKeyPath = conversationKeyPath + "/\(Conversation.SerializationKeys.compressedHash.rawValue)"
                let getValuesResult = await networking.database.getValues(at: hashKeyPath)

                switch getValuesResult {
                case let .success(values):
                    guard let string = values as? String else {
                        return .failure(.init(
                            "Failed to typecast values to string.",
                            metadata: [self, #file, #function, #line]
                        ))
                    }

                    return .success(.init(
                        .init(key: conversation.id.key, hash: string),
                        messageIDs: conversation.messageIDs,
                        messages: conversation.messages,
                        lastModifiedDate: conversation.lastModifiedDate,
                        participants: conversation.participants,
                        users: conversation.users
                    ))

                case let .failure(exception):
                    return .failure(exception)
                }
            }

            let participantsKeyPath = conversationKeyPath + "/\(Conversation.SerializationKeys.participants.rawValue)"
            let getValuesResult = await networking.database.getValues(at: participantsKeyPath)

            switch getValuesResult {
            case let .success(values):
                guard let array = values as? [String] else {
                    return .failure(.init(
                        "Failed to typecast values to array.",
                        metadata: [self, #file, #function, #line]
                    ))
                }

                var participants = [Participant]()

                for value in array {
                    let decodeResult = await Participant.decode(from: value)

                    switch decodeResult {
                    case let .success(participant):
                        participants.append(participant)

                    case let .failure(exception):
                        return .failure(exception)
                    }
                }

                guard participants.count == array.count else {
                    return .failure(.init(
                        "Mismatched ratio returned.",
                        metadata: [self, #file, #function, #line]
                    ))
                }

                guard let conversation = conversation.modifyKey(.participants, withValue: participants) else {
                    return .failure(.typeMismatch(
                        key: Conversation.SerializationKeys.participants.rawValue,
                        [self, #file, #function, #line]
                    ))
                }

                return await updateHash(conversation)

            case let .failure(exception):
                return .failure(exception)
            }
        }

        if let currentUserID {
            guard let currentUserParticipant = conversation.participants.first(where: { $0.userID == currentUserID }),
                  !currentUserParticipant.hasDeletedConversation else {
                Logger.log(
                    .init(
                        "Skipping message retrieval for conversation in which current user is not participating or has deleted.",
                        extraParams: ["ConversationIDKey": conversation.id.key,
                                      "ConversationIDHash": conversation.id.hash],
                        metadata: [self, #file, #function, #line]
                    ),
                    domain: .conversation
                )

                return await updateParticipants(conversation)
            }
        }

        let messagesKeyPath = conversationKeyPath + "/\(Conversation.SerializationKeys.messages.rawValue)"
        let getValuesResult = await networking.database.getValues(at: messagesKeyPath)

        switch getValuesResult {
        case let .success(values):
            guard let array = values as? [String] else {
                return .failure(.init(
                    "Failed to typecast values to array.",
                    metadata: [self, #file, #function, #line]
                ))
            }

            var filteredMessageIDs = array.filter { !(conversation.messages?.uniquedByID.map(\.id) ?? conversation.messageIDs).contains($0) }
            if filteredMessageIDs.isEmpty {
                filteredMessageIDs = conversation.messages?.uniquedByID.map(\.id) ?? []
            }

            filteredMessageIDs = filteredMessageIDs.unique

            guard !filteredMessageIDs.isEmpty else {
                return await updateParticipants(conversation)
            }

            guard let currentMessages = conversation.messages?.uniquedByID else {
                return .failure(.init(
                    "Messages have not been set.",
                    metadata: [self, #file, #function, #line]
                ))
            }

            let getMessagesResult = await networking.services.message.getMessages(ids: filteredMessageIDs)

            switch getMessagesResult {
            case let .success(messages):
                let updatedMessages = (currentMessages + messages).sorted(by: { $0.sentDate < $1.sentDate })
                guard let modified = conversation.modifyKey(.messages, withValue: updatedMessages) else {
                    return .failure(.typeMismatch(key: Conversation.SerializationKeys.messages, [self, #file, #function, #line]))
                }

                return await updateParticipants(modified)

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
            .filter({ $0.userID != currentUserID })
            .allSatisfy(\.hasDeletedConversation) else {
            guard let currentUserID else {
                return .init("No current user ID.", metadata: [self, #file, #function, #line])
            }

            return await hideConversation(conversation, forUser: currentUserID)
        }

        if let exception = await removeConversationFromUsers(
            userIDs: conversation.participants.map(\.userID),
            conversationIDKey: conversation.id.key
        ) {
            return exception
        }

        if let exception = await networking.services.message.deleteMessages(
            ids: conversation.messageIDs,
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

        return nil
    }

    private func hideConversation(_ conversation: Conversation, forUser userID: String) async -> Exception? {
        guard let currentParticipant = conversation.participants.first(where: { $0.userID == userID }) else {
            return .init(
                "This conversation does not contain the specified participant.",
                extraParams: ["UserID": userID],
                metadata: [self, #file, #function, #line]
            )
        }

        var newParticipants = conversation.participants.filter { $0.userID != userID }
        let newParticipant: Participant = .init(
            userID: currentParticipant.userID,
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

    private func removeConversationFromUsers(userIDs: [String], conversationIDKey: String) async -> Exception? {
        func removeConversationFromUser(userID: String, conversationIDKey: String) async -> Exception? {
            let commonParams = ["UserID": userID, "ConversationIDKey": conversationIDKey]

            guard !userID.isBangQualifiedEmpty,
                  !conversationIDKey.isBangQualifiedEmpty else {
                let exception = Exception("Passed arguments fail validation.", metadata: [self, #file, #function, #line])
                return exception.appending(extraParams: commonParams)
            }

            let getConversationIDStringsResult = await networking.services.conversation.getConversationIDStrings(for: userID)

            switch getConversationIDStringsResult {
            case var .success(conversationIDStrings):
                conversationIDStrings.removeAll(where: { $0.hasPrefix(conversationIDKey) })
                conversationIDStrings = conversationIDStrings.isBangQualifiedEmpty ? .bangQualifiedEmpty : conversationIDStrings

                let path = networking.config.paths.users
                if let exception = await networking.database.setValue(
                    conversationIDStrings,
                    forKey: "\(path)/\(userID)/\(User.SerializationKeys.conversationIDs.rawValue)"
                ) {
                    return exception.appending(extraParams: commonParams)
                }

            case let .failure(exception):
                return exception.appending(extraParams: commonParams)
            }

            return nil
        }

        for userID in userIDs {
            if let exception = await removeConversationFromUser(
                userID: userID,
                conversationIDKey: conversationIDKey
            ) {
                return exception
            }
        }

        return nil
    }
}
