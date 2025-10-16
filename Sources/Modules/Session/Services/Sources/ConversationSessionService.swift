//
//  ConversationSessionService.swift
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

public final class ConversationSessionService {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ConversationSessionService

    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Properties

    public private(set) var currentConversation: Conversation?

    private var completeMessageArray: [Message]?
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
            reactionMetadata: currentConversation.reactionMetadata,
            users: currentConversation.users
        )
    }

    public var sync: ConversationSyncService { .init() }

    // MARK: - Add Messages

    public func addMessages(_ messages: [Message], to conversation: Conversation) async -> Callback<Conversation, Exception> {
        guard !messages.isEmpty else {
            return .failure(.init(
                "No messages provided.",
                metadata: .init(sender: self)
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

    public func setCurrentConversation(_ currentConversation: Conversation?) {
        completeMessageArray = currentConversation?.messages?.unique.sortedByAscendingSentDate
        self.currentConversation = withMessagesOffset(currentConversation?.withMessagesSortedByAscendingSentDate)
    }

    // MARK: - Message Offset

    public func incrementMessageOffset() {
        guard let fullConversation else { return }
        messageOffset += Floats.messageOffsetIncrement
        currentConversation = withMessagesOffset(fullConversation)
    }

    public func incrementMessageOffset(to messageID: String) {
        guard let fullConversation,
              fullConversation.messageIDs.contains(messageID),
              fullConversation.messages?.map(\.id).contains(messageID) == true else { return }

        while currentConversation?.messages?.map(\.id).contains(messageID) == false {
            messageOffset += 1
            currentConversation = withMessagesOffset(fullConversation)
        }
    }

    public func resetMessageOffset() {
        messageOffset = Floats.defaultMessageOffset
    }

    // MARK: - Deletion

    public func deleteConversation(_ conversation: Conversation, forced: Bool = false) async -> Exception? {
        if !forced {
            guard conversation.participants
                .filter({ $0.userID != User.currentUserID })
                .allSatisfy(\.hasDeletedConversation) else {
                guard let currentUserID = User.currentUserID else {
                    return .init(
                        "Current user ID has not been set.",
                        metadata: .init(sender: self)
                    )
                }

                return await hideConversation(conversation, forUser: currentUserID)
            }
        }

        if let exception = await networking.conversationService.removeConversationFromUsers(
            userIDs: conversation.participants.map(\.userID),
            conversationIDKey: conversation.id.key
        ) {
            return exception
        }

        if let exception = await networking.messageService.deleteMessages(
            ids: conversation.messageIDs,
            in: conversation,
            updateConversationHash: false
        ) {
            return exception
        }

        let path = NetworkPath.conversations.rawValue
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
                userInfo: ["UserID": userID],
                metadata: .init(sender: self)
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

        let updateValueResult = await conversation.updateValue(newParticipants, forKey: .participants)

        switch updateValueResult {
        case .success: // NIT: We don't care about the result because updateValue adds the updated conversation to the archive for us.
            return nil

        case let .failure(exception):
            return exception
        }
    }

    private func withMessagesOffset(_ conversation: Conversation?) -> Conversation? {
        let amountToGet = Int(messageOffset)
        guard let conversation,
              let messages = conversation.messages?.unique,
              messages.count > amountToGet else { return conversation }

        return .init(
            conversation.id,
            messageIDs: conversation.messageIDs,
            messages: messages.reversed()[0 ... amountToGet].reversed(),
            metadata: conversation.metadata,
            participants: conversation.participants,
            reactionMetadata: conversation.reactionMetadata,
            users: conversation.users
        )
    }
}
