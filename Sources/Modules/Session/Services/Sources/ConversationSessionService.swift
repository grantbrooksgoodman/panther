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

final class ConversationSessionService: @unchecked Sendable {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ConversationSessionService

    // MARK: - Types

    private enum CurrentConversationReference {
        case draft(Conversation)
        case none
        case stored(idKey: String)
    }

    // MARK: - Dependencies

    @Dependency(\.clientSession.conversationObserver) private var conversationObserver: ConversationObserverService
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.clientSession.store) private var sessionStore: SessionStore

    // MARK: - Properties

    private(set) var displayedMessages: [Message] = []

    private var changeHandlerID: UUID?
    private var currentConversationReference: CurrentConversationReference = .none
    private var messageOffset = Floats.defaultMessageOffset

    // MARK: - Computed Properties

    var currentConversation: Conversation? {
        switch currentConversationReference {
        case let .draft(conversation): conversation
        case let .stored(idKey): sessionStore.getConversation(idKey: idKey)
        case .none: nil
        }
    }

    var sync: ConversationSyncService {
        .init()
    }

    private var hydratedMessages: [Message] {
        guard let currentConversation else { return [] }
        return (currentConversation.messages ?? [])
            .hydrated(with: currentConversation.activities)
    }

    // MARK: - Init

    init() {
        changeHandlerID = SessionStore.addChangeHandler { [weak self] change in
            guard let self else { return }
            handleStoreChange(change)
        }
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
        guard let conversation else { return clearPointer() }

        let previousReference = currentConversationReference

        if conversation.isEmpty || conversation.isMock {
            currentConversationReference = .draft(conversation)
        } else {
            // Ensures the store contains the conversation before setting the pointer.
            sessionStore.upsertConversation(conversation)
            currentConversationReference = .stored(idKey: conversation.id.key)

            // First send in a new chat: start observing
            // now that the conversation is stored.
            if case .draft = previousReference {
                conversationObserver.startObserving(
                    conversationIDKey: conversation.id.key
                )
            }
        }

        updateDisplayedMessages()
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
              messageOffset < offsetMessages.count {
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

    private func clearPointer() {
        conversationObserver.stopObserving()
        currentConversationReference = .none
        displayedMessages = []
    }

    private func handleStoreChange(_ change: SessionStoreChange) {
        guard case let .stored(idKey) = currentConversationReference else { return }

        switch change {
        case let .conversations(upsertedIDKeys, removedIDKeys):
            if removedIDKeys.contains(idKey) {
                Logger.log(
                    .init(
                        "Current conversation was removed from the store.",
                        isReportable: false,
                        userInfo: ["ConversationIDKey": idKey],
                        metadata: .init(sender: self)
                    ),
                    domain: .conversation
                )

                return clearPointer()
            }

            guard upsertedIDKeys.contains(idKey) else { return }
            updateDisplayedMessages()

        case let .messages(upsertedIDs, removedIDs):
            let affectedIDs = upsertedIDs.union(removedIDs)
            guard let conversation = currentConversation,
                  !Set(conversation.messageIDs).isDisjoint(with: affectedIDs) else { return }
            updateDisplayedMessages()

        case .users:
            break
        }
    }

    private func hideConversation(
        _ conversation: Conversation,
        forUser userID: String
    ) async throws(Exception) {
        guard conversation
            .participants
            .contains(where: { $0.userID == userID }) else {
            throw Exception(
                "This conversation does not contain the specified participant.",
                userInfo: ["UserID": userID],
                metadata: .init(sender: self)
            )
        }

        // Single-field fan-out write instead of replacing
        // the entire participants array.
        let conversationPath = [
            NetworkPath.conversations.rawValue,
            conversation.id.key,
        ].joined(separator: "/")

        let participantPath = [
            conversationPath,
            Conversation.SerializableKey.participants.rawValue,
            userID,
            Participant.SerializableKey.hasDeletedConversation.rawValue,
        ].joined(separator: "/")

        // Compute updated hash with the deletion applied.
        let updatedConversation = conversation.copying(
            participants: conversation.participants.map { participant in
                guard participant.userID == userID else { return participant }
                return Participant(
                    userID: participant.userID,
                    hasDeletedConversation: true,
                    isTyping: participant.isTyping
                )
            }
        )

        let newHash = updatedConversation.encodedHash
        var updates: [String: Any] = [participantPath: true]
        updates["\(conversationPath)/\(Conversation.SerializableKey.encodedHash.rawValue)"] = newHash

        for participant in conversation.participants {
            let tokenPath = [
                NetworkPath.users.rawValue,
                participant.userID,
                User.SerializableKey.conversationIDs.rawValue,
                conversation.id.key,
            ].joined(separator: "/")

            updates[tokenPath] = newHash
        }

        try await networking.database.commit(updates)

        // Upsert the updated conversation to the session store.
        sessionStore.upsertConversation(
            updatedConversation.copying(
                id: .init(
                    key: conversation.id.key,
                    hash: newHash
                )
            )
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
        let amountToGet = messageOffset
        guard messages.unique.count > amountToGet else { return messages }
        return Array(
            messages.unique.reversed()[0 ... amountToGet].reversed()
        )
    }
}
