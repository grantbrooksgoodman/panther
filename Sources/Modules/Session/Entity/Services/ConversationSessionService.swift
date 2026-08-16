//
//  ConversationSessionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

/// The service that manages the current conversation and its displayed messages.
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

    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Properties

    /// The messages currently displayed for the current conversation, including any outbox
    /// entries.
    @LockIsolated private(set) var displayedMessages = [Message]()

    @LockIsolated private var currentConversationReference = CurrentConversationReference.none
    @LockIsolated private var messageOffset = Floats.defaultMessageOffset
    @SharedEvent(\.messageOutboxDidChange) private var messageOutboxDidChange
    @SharedEvent(\.sessionStoreDidChange) private var sessionStoreDidChange

    // MARK: - Computed Properties

    /// The current conversation, or `nil` if none is set.
    var currentConversation: Conversation? {
        switch currentConversationReference {
        case let .draft(conversation): conversation
        case let .stored(idKey): clientSession.store.getConversation(idKey: idKey)
        case .none: nil
        }
    }

    private var hydratedMessages: [Message] {
        guard let currentConversation else { return [] }
        return (currentConversation.messages ?? [])
            .hydrated(with: currentConversation.activities)
    }

    // MARK: - Init

    init() {
        Task { @MainActor [weak self] in
            guard let outboxChanges = self?.messageOutboxDidChange.events else { return }
            for await _ in outboxChanges {
                self?.updateDisplayedMessages()
            }
        }

        Task { @MainActor [weak self] in
            guard let sessionStoreChanges = self?.sessionStoreDidChange.events else { return }
            for await change in sessionStoreChanges {
                guard [.conversations, .messages].contains(change.kind) else { continue }
                self?.handleStoreChange(change)
            }
        }
    }

    // MARK: - Add Messages

    /// Appends the given messages to the given conversation and writes the result.
    ///
    /// - Parameters:
    ///   - messages: The messages to append.
    ///   - conversation: The conversation to append the messages to.
    ///
    /// - Returns: The updated conversation.
    ///
    /// - Throws: An `Exception` if no messages are provided or the write fails.
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
            !$0.isMock && !$0.isOutboxMessage
        }.sortedByAscendingSentDate

        return try await conversation.update(
            \.messages,
            to: appendedMessages
        )
    }

    // MARK: - Set Current Conversation

    /// Sets the current conversation, or clears it when `nil`.
    ///
    /// Draft conversations, which are empty or mock, are held locally. Stored conversations are
    /// upserted into the session store and observed for real-time updates.
    ///
    /// - Parameter conversation: The conversation to set as current, or `nil` to clear it.
    func setCurrentConversation(_ conversation: Conversation?) {
        guard let conversation else { return clearPointer() }
        let previousReference = currentConversationReference

        if conversation.isEmpty || conversation.isMock {
            currentConversationReference = .draft(conversation)
        } else {
            // Ensures the store contains the conversation before setting the pointer.
            clientSession.store.upsertConversation(conversation)
            currentConversationReference = .stored(idKey: conversation.id.key)

            // First send in a new chat: start observing
            // now that the conversation is stored.
            if case .draft = previousReference {
                clientSession
                    .sync
                    .conversationObserver
                    .startObserving(
                        conversationIDKey: conversation.id.key
                    )
            }
        }

        updateDisplayedMessages()
    }

    // MARK: - Message Offset

    /// Increases the number of displayed messages by a fixed increment.
    func incrementMessageOffset() {
        guard currentConversation != nil else { return }
        messageOffset += Floats.messageOffsetIncrement
        updateDisplayedMessages()
    }

    /// Increases the number of displayed messages until the message with the given identifier is
    /// displayed.
    ///
    /// - Parameter messageID: The identifier of the message to reveal.
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

    /// Resets the number of displayed messages to the default.
    func resetMessageOffset() {
        messageOffset = Floats.defaultMessageOffset
    }

    // MARK: - Update Displayed Messages

    /// Recomputes the current conversation's displayed messages, including any outbox entries.
    ///
    /// Store-change events land on a later main actor job; a caller reloading UI in the same job as
    /// an upsert can call this first to refresh immediately.
    func updateDisplayedMessages() {
        var messages = withMessagesOffset(
            hydratedMessages.offsetFromCurrentUserAdditionDate(
                activities: currentConversation?.activities
            ).sortedByAscendingSentDate
        )

        if let conversationIDKey = currentConversation?.id.key {
            messages.append(
                contentsOf: clientSession
                    .outbox
                    .entries(forConversationIDKey: conversationIDKey)
                    .map(\.asDisplayMessage)
            )
        }

        displayedMessages = messages.uniquedByID
    }

    // MARK: - Deletion

    /// Deletes or hides the given conversation.
    ///
    /// When the deletion is not forced and the other participants have not all deleted the
    /// conversation, it is hidden for the current user instead of deleted for everyone. Otherwise,
    /// the conversation, its messages, and its participants' references to it are removed.
    ///
    /// - Parameters:
    ///   - conversation: The conversation to delete.
    ///   - forced: A Boolean value that determines whether to delete the conversation outright
    ///     rather than hide it.
    ///
    /// - Throws: An `Exception` if the current user identifier has not been set or the write fails.
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
        clientSession.sync.conversationObserver.stopObserving()
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

                // Dismiss the chat page when the current conversation
                // is removed (e.g., deleted remotely by another
                // participant).
                Task { @MainActor in
                    navigation.navigate(to: .userContent(.stack([])))
                    if RuntimeStorage.shouldNotifyOfConversationAvailability {
                        Toast.show(
                            .init(
                                .banner(style: .info),
                                message: "This conversation is no longer available."
                            ),
                            translating: Toast.TranslationOptionKey.allCases
                        )
                    } else {
                        RuntimeStorage.remove(.shouldNotifyOfConversationAvailability)
                    }
                }

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
        clientSession.store.upsertConversation(
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

// swiftlint:enable file_length type_body_length
