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

final class ConversationSessionService {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ConversationSessionService

    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.clientSession.store) private var sessionStore: SessionStore

    // MARK: - Properties

    private(set) var currentConversation: Conversation?
    private(set) var displayedMessages: [Message] = []

    private var messageOffset = Floats.defaultMessageOffset

    // MARK: - Computed Properties

    var sync: ConversationSyncService {
        .init()
    }

    private var hydratedMessages: [Message] {
        guard let currentConversation else { return [] }
        return (currentConversation.messages ?? [])
            .hydrated(with: currentConversation.activities)
    }

    // MARK: - Add Messages

    func addMessages(
        _ messages: [Message],
        to conversation: Conversation
    ) async throws(Exception) -> Conversation {
        guard !messages.isEmpty else {
            throw Exception(
                "No messages provided.",
                metadata: .init(sender: self)
            )
        }

        var appendedMessages = conversation.messages ?? []
        appendedMessages.append(contentsOf: messages)
        appendedMessages = appendedMessages.filter {
            !$0.isMock
        }.sortedByAscendingSentDate

        return try await conversation.update(
            \.messages,
            to: appendedMessages
        )
    }

    // MARK: - Set Current Conversation

    func setCurrentConversation(_ conversation: Conversation?) {
        guard let conversation else {
            currentConversation = nil
            displayedMessages = []
            return
        }

        currentConversation = conversation
        updateDisplayedMessages()
        sessionStore.upsertConversation(conversation)
    }

    // MARK: - Message Offset

    func incrementMessageOffset() {
        guard currentConversation != nil else { return }
        messageOffset += Floats.messageOffsetIncrement
        updateDisplayedMessages()
    }

    func incrementMessageOffset(to messageID: String) {
        guard let currentConversation,
              currentConversation.messageIDs.contains(messageID),
              (currentConversation.messages ?? []).map(\.id).contains(messageID) else { return }

        let offsetMessages = hydratedMessages
            .offsetFromCurrentUserAdditionDate(
                activities: currentConversation.activities
            )

        guard offsetMessages.map(\.id).contains(messageID) else { return }
        while !displayedMessages.map(\.id).contains(messageID),
              Int(messageOffset) < offsetMessages.count {
            messageOffset += 1
            displayedMessages = withMessagesOffset(offsetMessages)
        }
    }

    func resetMessageOffset() {
        messageOffset = Floats.defaultMessageOffset
    }

    // MARK: - Deletion

    func deleteConversation(
        _ conversation: Conversation,
        forced: Bool = false
    ) async throws(Exception) {
        if !forced {
            guard conversation.participants
                .filter({ $0.userID != User.currentUserID })
                .allSatisfy(\.hasDeletedConversation) else {
                guard let currentUserID = User.currentUserID else {
                    throw Exception(
                        "Current user ID has not been set.",
                        metadata: .init(sender: self)
                    )
                }

                return try await hideConversation(
                    conversation,
                    forUser: currentUserID
                )
            }
        }

        try await networking.conversationService.removeConversationFromUsers(
            userIDs: conversation.participants.map(\.userID),
            conversationIDKey: conversation.id.key
        )

        try await networking.messageService.deleteMessages(
            ids: conversation.messageIDs,
            in: conversation,
            updateConversationHash: false
        )

        try await networking.database.setValue(
            NSNull(),
            forKey: [
                NetworkPath.conversations.rawValue,
                conversation.id.key,
            ].joined(separator: "/")
        )

        if currentConversation?.id.key == conversation.id.key {
            setCurrentConversation(nil)
        }
    }

    // MARK: - Auxiliary

    private func hideConversation(
        _ conversation: Conversation,
        forUser userID: String
    ) async throws(Exception) {
        guard let currentParticipant = conversation
            .participants
            .first(where: { $0.userID == userID }) else {
            throw Exception(
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

        // NIT: We don't care about the result because update adds the updated conversation to the archive for us.
        _ = try await conversation.update(
            \.participants,
            to: newParticipants
        )

        if currentConversation?.id.key == conversation.id.key {
            setCurrentConversation(nil)
        }
    }

    private func updateDisplayedMessages() {
        displayedMessages = withMessagesOffset(
            hydratedMessages.offsetFromCurrentUserAdditionDate(
                activities: currentConversation?.activities
            ).sortedByAscendingSentDate
        )
    }

    private func withMessagesOffset(
        _ messages: [Message]
    ) -> [Message] {
        let amountToGet = Int(messageOffset)
        guard messages.unique.count > amountToGet else { return messages }
        return Array(
            messages.unique.reversed()[0 ... amountToGet].reversed()
        )
    }
}
