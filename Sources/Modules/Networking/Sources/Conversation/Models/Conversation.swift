//
//  Conversation.swift
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

@RemotelyUpdatable
struct Conversation: Codable, EncodedHashable, Hashable {
    // MARK: - Properties

    static let empty: Conversation = .init(
        .init(key: "", hash: ""),
        activities: nil,
        messageIDs: [],
        metadata: .empty(userIDs: []),
        participants: [],
        reactionMetadata: nil
    )

    let activities: [Activity]?
    let id: ConversationID
    let messageIDs: [String]
    let metadata: ConversationMetadata
    let participants: [Participant]
    let reactionMetadata: [ReactionMetadata]?

    // MARK: - Computed Properties

    var hashFactors: [String] {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        var factors = [id.key]
        factors.append(contentsOf: activities?.map(\.encodedHash) ?? [])
        factors.append(contentsOf: messageIDs.filter { $0.hasPrefix("-") })
        factors.append(metadata.name)
        factors.append(metadata.imageHash ?? .bangQualifiedEmpty)
        factors.append(metadata.isPenPalsConversation.description)
        factors.append(dateFormatter.string(from: metadata.lastModifiedDate))
        factors.append(contentsOf: metadata.messageRecipientConsentAcknowledgementData.map(\.encoded))
        factors.append(contentsOf: metadata.penPalsSharingData.map(\.encoded))
        factors.append(metadata.requiresConsentFromInitiator == nil ? .bangQualifiedEmpty : metadata.requiresConsentFromInitiator!.description)
        // Content-version only: userID + hasDeletedConversation.
        // isTyping is excluded so typing writes do not mint
        // version tokens; presence propagates via the observer.
        factors.append(contentsOf: participants.map {
            "\($0.userID) | \($0.hasDeletedConversation)"
        })
        factors.append(contentsOf: reactionMetadata?.map(\.encodedHash) ?? [])
        return factors.sorted()
    }

    /// Resolves messages from the session store using this conversation's `messageIDs`.
    ///
    /// Returns `nil` if the conversation does not include the current user or if no messages are in the store.
    var messages: [Message]? {
        @Dependency(\.clientSession.store) var sessionStore: SessionStore
        let messages = messageIDs.compactMap { sessionStore.messages[$0] }

        // Session store does not store system messages.
        if messages.count != messageIDs.count,
           isVisibleForCurrentUser {
            return nil
        }

        return messages.isEmpty ? nil : messages
    }

    /// Resolves non-current-user participants from the session store.
    ///
    /// Returns `nil` if no matching users are in the store.
    var users: [User]? {
        @Dependency(\.clientSession.store) var sessionStore: SessionStore
        let userIDs = participants.map(\.userID).filter { $0 != User.currentUserID }
        let users = userIDs.compactMap { sessionStore.users[$0] }
        guard users.count == userIDs.count else { return nil }
        return users.isEmpty ? nil : users
    }

    // MARK: - Init

    init(
        _ id: ConversationID,
        activities: [Activity]?,
        messageIDs: [String],
        metadata: ConversationMetadata,
        participants: [Participant],
        reactionMetadata: [ReactionMetadata]?
    ) {
        self.id = id
        self.activities = activities
        self.messageIDs = messageIDs
        self.metadata = metadata
        self.participants = participants
        self.reactionMetadata = reactionMetadata
    }

    // MARK: - Resolve Messages

    /// Fetches messages from the network and upserts them to
    /// the session store.
    ///
    /// When `ids` is `nil`, all non-system message identifiers
    /// on this conversation are fetched. When `ids` is
    /// provided, only the specified messages are fetched.
    ///
    /// After this method returns, the fetched messages are
    /// available through the ``messages`` computed property.
    ///
    /// - Parameter ids: A set of message identifiers to fetch.
    ///   Pass `nil` to fetch all non-system messages.
    func resolveMessages(
        ids: Set<String>? = nil
    ) async throws(Exception) {
        @Dependency(\.networking.messageService) var messageService: MessageService
        @Dependency(\.clientSession.store) var sessionStore: SessionStore

        if let ids {
            // Fetched from network; bypasses RemotelyUpdatable.update.
            try await sessionStore.upsertMessages(Set(
                ids
                    .filter { messageIDs.contains($0) }
                    .map { try await messageService.getMessage(id: $0) }
            ))
            return
        }

        let filteredMessageIDs = filteringSystemMessages.messageIDs
        let fetchedMessages = try await messageService.getMessages(
            ids: filteredMessageIDs
        )

        guard !fetchedMessages.isEmpty,
              fetchedMessages.count == filteredMessageIDs.count else {
            throw Exception(
                "Mismatched ratio returned.",
                metadata: .init(sender: self)
            )
        }

        Logger.log(
            .init(
                "Resolved messages for conversation.",
                isReportable: false,
                userInfo: ["ConversationID": id.encoded],
                metadata: .init(sender: self)
            ),
            domain: .conversation
        )

        // Fetched from network; bypasses RemotelyUpdatable.update.
        sessionStore.upsertMessages(Set(fetchedMessages))
    }

    // MARK: - Resolve Users

    /// Fetches non-current-user participants from the network
    /// and upserts them to the session store.
    ///
    /// By default, this method returns early when all
    /// participants are already available through the
    /// ``users`` computed property. Pass `forceUpdate` to
    /// bypass the cache and re-fetch regardless.
    ///
    /// - Parameter forceUpdate: When `true`, disregards the
    ///   cache and fetches all participants from the network.
    func resolveUsers(
        forceUpdate: Bool = false
    ) async throws(Exception) {
        @Dependency(\.networking) var networking: NetworkServices
        @Dependency(\.clientSession.store) var sessionStore: SessionStore

        let userInfo = ["ConversationID": id.encoded]
        if forceUpdate {
            networking.database.setGlobalCacheStrategy(.disregardCache)
        } else {
            guard users == nil ||
                users!.count != participants.count - 1 else { return }
        }

        defer {
            if forceUpdate {
                networking.database.setGlobalCacheStrategy(nil)
            }
        }

        let userIDs = participants.map(\.userID).filter { $0 != User.currentUserID }
        guard !userIDs.isBangQualifiedEmpty else {
            throw Exception(
                "No participants for this conversation.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        let fetchedUsers: [User]
        do {
            fetchedUsers = try await networking.userService.getUsers(
                ids: userIDs
            )
        } catch {
            throw error.appending(userInfo: userInfo)
        }

        guard !fetchedUsers.isEmpty,
              fetchedUsers.count == userIDs.count else {
            throw Exception(
                "Mismatched ratio returned.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        Logger.log(
            .init(
                "Resolved users for conversation.",
                isReportable: false,
                userInfo: ["ConversationID": id.encoded],
                metadata: .init(sender: self)
            ),
            domain: .conversation
        )

        // Fetched from network; bypasses RemotelyUpdatable.update.
        sessionStore.upsertUsers(Set(fetchedUsers))
    }

    // MARK: - Update Read Date

    func updateReadDate(
        for messages: [Message]
    ) async throws(Exception) {
        @Dependency(\.networking.database) var database: DatabaseDelegate
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        @Dependency(\.clientSession.store) var sessionStore: SessionStore

        guard !messages.isEmpty else {
            throw Exception(
                "No messages provided.",
                metadata: .init(sender: self)
            )
        }

        guard let currentUserID = User.currentUserID else {
            throw Exception(
                "Current user ID has not been set.",
                metadata: .init(sender: self)
            )
        }

        let now = Date.now
        let readReceipt = ReadReceipt(
            userID: currentUserID,
            readDate: now
        )

        let unreadMessages = messages.filter {
            $0.currentUserReadReceipt == nil
        }

        guard !unreadMessages.isEmpty else { return }
        var updates = [String: Any]()
        var updatedMessages = [Message]()

        // Per-message read receipt entries. Array retained:
        // a message's receipts are small and only ever
        // written by readers of that message. Group-chat
        // concurrent-readers remain last-writer-wins at
        // per-message granularity (accepted residual).
        for message in unreadMessages {
            let updatedReceipts = (
                (
                    message
                        .readReceipts?
                        .filter { $0.userID != currentUserID } ?? []
                ) + [readReceipt]
            ).unique

            let path = [
                NetworkPath.messages.rawValue,
                message.id,
                Message.SerializableKey.readReceipts.rawValue,
            ].joined(separator: "/")

            updates[path] = updatedReceipts.map(\.encoded)
            updatedMessages.append(
                message.copying(readReceipts: updatedReceipts)
            )
        }

        // For 1:1 conversations, add lastModifiedDate +
        // hash + participant token entries.
        var updatedConversation: Conversation?
        if participants.count == 2 {
            let conversationPath = [
                NetworkPath.conversations.rawValue,
                id.key,
            ].joined(separator: "/")

            let lastModifiedPath = [
                conversationPath,
                Conversation.SerializableKey.metadata.rawValue,
                ConversationMetadata.SerializableKey.lastModifiedDate.rawValue,
            ].joined(separator: "/")

            updates[lastModifiedPath] = dateFormatter.string(from: now)

            let withMetadata = copying(
                metadata: metadata.copyWith(lastModifiedDate: now)
            )

            let newHash = withMetadata.encodedHash

            updates["\(conversationPath)/\(Conversation.SerializableKey.encodedHash.rawValue)"] = newHash

            for participant in participants {
                let tokenPath = [
                    NetworkPath.users.rawValue,
                    participant.userID,
                    User.SerializableKey.conversationIDs.rawValue,
                    id.key,
                ].joined(separator: "/")

                updates[tokenPath] = newHash
            }

            updatedConversation = withMetadata.copying(
                id: .init(
                    key: id.key,
                    hash: newHash
                )
            )
        }

        try await database.commit(updates)
        sessionStore.upsertMessages(Set(updatedMessages))
        if let updatedConversation {
            sessionStore.upsertConversation(updatedConversation)
        }

        Logger.log(
            "Updated read date for \(unreadMessages.count) message\(unreadMessages.count == 1 ? "" : "s").",
            domain: .conversation,
            sender: self
        )
    }

    // MARK: - Hashable Conformance

    func hash(into hasher: inout Hasher) {
        hasher.combine(id.key)
        hasher.combine(id.hash)
    }
}
