//
//  ConversationSessionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable type_body_length

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public final class ConversationSessionService {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ConversationSessionService

    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: Networking

    // MARK: - Properties

    public private(set) var currentConversation: Conversation?

    private var completeMessageArray: [Message]?
    @Persistent(.currentUserID) private var currentUserID: String?
    private var messageOffset = Floats.defaultMessageOffset

    // MARK: - Computed Properties

    /// The value of `currentConversation` with the fully populated `messages` array.
    public var fullConversation: Conversation? {
        guard let currentConversation else { return nil }
        return .init(
            currentConversation.id,
            messageIDs: currentConversation.messageIDs,
            messages: completeMessageArray,
            metadata: currentConversation.metadata,
            participants: currentConversation.participants,
            users: currentConversation.users
        )
    }

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
        appendedMessages = appendedMessages.filter { !$0.isMock }.sortedByAscendingSentDate

        switch await conversation.updateValue(appendedMessages, forKey: .messages) {
        case let .success(conversation):
            return .success(conversation)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    // MARK: - Set Current Conversation

    public func setCurrentConversation(_ currentConversation: Conversation) {
        completeMessageArray = currentConversation.messages?.unique.sortedByAscendingSentDate
        self.currentConversation = withMessagesOffset(currentConversation.withMessagesSortedByAscendingSentDate)
    }

    // MARK: - Message Offset

    public func incrementMessageOffset() {
        guard let fullConversation else { return }
        messageOffset += Floats.messageOffsetIncrement
        currentConversation = withMessagesOffset(fullConversation)
    }

    public func resetMessageOffset() {
        messageOffset = Floats.defaultMessageOffset
    }

    // MARK: - Value Updating

    public func updateConversation(_ conversation: Conversation) async -> Callback<Conversation, Exception> {
        let conversationKeyPath = "\(networking.config.paths.conversations)/\(conversation.id.key)"

        Logger.log(
            "Updating conversation with ID \(conversation.id.key).",
            domain: .conversation,
            metadata: [self, #file, #function, #line]
        )

        guard let currentUserParticipant = conversation.currentUserParticipant,
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

            return await updateData(conversation)
        }

        guard let currentMessages = conversation.messages?.uniquedByID else {
            if let exception = await conversation.setMessages() {
                return .failure(exception)
            }

            return await updateConversation(conversation)
        }

        let messagesKeyPath = conversationKeyPath + "/\(Conversation.SerializationKeys.messages.rawValue)"
        let getValuesResult = await networking.database.getValues(at: messagesKeyPath)

        switch getValuesResult {
        case let .success(values):
            guard let array = values as? [String] else {
                return .failure(.typecastFailed("array", metadata: [self, #file, #function, #line]))
            }

            var filteredMessageIDs = array.filter { !currentMessages.map(\.id).contains($0) }
            if filteredMessageIDs.isEmpty {
                filteredMessageIDs = currentMessages.map(\.id)
            }

            filteredMessageIDs = filteredMessageIDs.unique

            guard !filteredMessageIDs.isEmpty else {
                return await updateData(conversation)
            }

            let getMessagesResult = await networking.services.message.getMessages(ids: filteredMessageIDs)

            switch getMessagesResult {
            case let .success(messages):
                let updatedMessages = (currentMessages + messages).sorted(by: { $0.sentDate < $1.sentDate })
                guard let modified = conversation.modifyKey(.messages, withValue: updatedMessages) else {
                    return .failure(.typeMismatch(key: Conversation.SerializationKeys.messages, [self, #file, #function, #line]))
                }

                return await updateData(modified)

            case let .failure(exception):
                return .failure(exception)
            }

        case let .failure(exception):
            return .failure(exception)
        }
    }

    private func updateData(_ conversation: Conversation) async -> Callback<Conversation, Exception> {
        let updateParticipantsResult = await updateParticipants(conversation)

        switch updateParticipantsResult {
        case let .success(conversation):
            let updateMetadataResult = await updateMetadata(conversation)

            switch updateMetadataResult {
            case let .success(conversation):
                return await updateHash(conversation)

            case let .failure(exception):
                return .failure(exception)
            }

        case let .failure(exception):
            return .failure(exception)
        }
    }

    private func updateHash(_ conversation: Conversation) async -> Callback<Conversation, Exception> {
        let conversationKeyPath = "\(networking.config.paths.conversations)/\(conversation.id.key)"
        let hashKeyPath = conversationKeyPath + "/\(Conversation.SerializationKeys.encodedHash.rawValue)"
        let getValuesResult = await networking.database.getValues(at: hashKeyPath, cacheStrategy: .disregardCache)

        switch getValuesResult {
        case let .success(values):
            guard let string = values as? String else {
                return .failure(.typecastFailed("string", metadata: [self, #file, #function, #line]))
            }

            return .success(.init(
                .init(key: conversation.id.key, hash: string),
                messageIDs: conversation.messageIDs,
                messages: conversation.messages,
                metadata: conversation.metadata,
                participants: conversation.participants,
                users: conversation.users
            ))

        case let .failure(exception):
            return .failure(exception)
        }
    }

    private func updateMetadata(_ conversation: Conversation) async -> Callback<Conversation, Exception> {
        let conversationKeyPath = "\(networking.config.paths.conversations)/\(conversation.id.key)"
        let metadataKeyPath = conversationKeyPath + "/\(Conversation.SerializationKeys.metadata.rawValue)"
        let getValuesResult = await networking.database.getValues(at: metadataKeyPath)

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .failure(.typecastFailed("dictionary", metadata: [self, #file, #function, #line]))
            }

            let decodeResult = await ConversationMetadata.decode(from: dictionary)

            switch decodeResult {
            case let .success(metadata):
                guard let conversation = conversation.modifyKey(.metadata, withValue: metadata) else {
                    return .failure(.typeMismatch(
                        key: Conversation.SerializationKeys.metadata.rawValue,
                        [self, #file, #function, #line]
                    ))
                }

                return .success(conversation)

            case let .failure(exception):
                return .failure(exception)
            }

        case let .failure(exception):
            return .failure(exception)
        }
    }

    private func updateParticipants(_ conversation: Conversation) async -> Callback<Conversation, Exception> {
        let conversationKeyPath = "\(networking.config.paths.conversations)/\(conversation.id.key)"
        let participantsKeyPath = conversationKeyPath + "/\(Conversation.SerializationKeys.participants.rawValue)"
        let getValuesResult = await networking.database.getValues(at: participantsKeyPath)

        switch getValuesResult {
        case let .success(values):
            guard let array = values as? [String] else {
                return .failure(.typecastFailed("array", metadata: [self, #file, #function, #line]))
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

            return .success(conversation)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    // MARK: - Deletion

    public func deleteConversation(_ conversation: Conversation, forced: Bool = false) async -> Exception? {
        if !forced {
            guard conversation.participants
                .filter({ $0.userID != currentUserID })
                .allSatisfy(\.hasDeletedConversation) else {
                guard let currentUserID else {
                    return .init("No current user ID.", metadata: [self, #file, #function, #line])
                }

                return await hideConversation(conversation, forUser: currentUserID)
            }
        }

        if let exception = await networking.services.conversation.removeConversationFromUsers(
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
    }

    private func withMessagesOffset(_ conversation: Conversation) -> Conversation {
        let amountToGet = Int(messageOffset)
        guard let messages = conversation.messages?.unique,
              messages.count > amountToGet else { return conversation }

        return .init(
            conversation.id,
            messageIDs: conversation.messageIDs,
            messages: messages.reversed()[0 ... amountToGet].reversed(),
            metadata: conversation.metadata,
            participants: conversation.participants,
            users: conversation.users
        )
    }
}

// swiftlint:enable type_body_length
