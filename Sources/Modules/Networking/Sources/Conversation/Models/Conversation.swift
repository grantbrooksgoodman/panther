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
        factors.append(metadata.imageData?.base64EncodedString() ?? .bangQualifiedEmpty)
        factors.append(metadata.isPenPalsConversation.description)
        factors.append(dateFormatter.string(from: metadata.lastModifiedDate))
        factors.append(contentsOf: metadata.messageRecipientConsentAcknowledgementData.map(\.encoded))
        factors.append(contentsOf: metadata.penPalsSharingData.map(\.encoded))
        factors.append(metadata.requiresConsentFromInitiator == nil ? .bangQualifiedEmpty : metadata.requiresConsentFromInitiator!.description)
        factors.append(contentsOf: participants.map(\.encoded))
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

    /// Fetches messages from the network and upserts them to the session store.
    ///
    /// - Parameter ids: If provided, only re-fetches these specific message IDs. Otherwise fetches all non-system messages.
    func resolveMessages(
        ids: Set<String>? = nil
    ) async throws(Exception) {
        @Dependency(\.networking.messageService) var messageService: MessageService
        @Dependency(\.clientSession.store) var sessionStore: SessionStore

        if let ids {
            for id in ids {
                let userInfo: [String: Any] = [
                    "ConversationIDKey": self.id.key,
                    "MessageID": id,
                ]

                guard messageIDs.contains(id) else {
                    throw Exception(
                        "No message with the provided ID exists in this conversation.",
                        userInfo: userInfo,
                        metadata: .init(sender: self)
                    )
                }

                let message: Message
                do {
                    message = try await messageService.getMessage(id: id)
                } catch {
                    throw error.appending(userInfo: userInfo)
                }

                sessionStore.upsertMessages([message])
            }

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

        sessionStore.upsertMessages(fetchedMessages)
    }

    // MARK: - Resolve Users

    /// Fetches users from the network and upserts them to the session store.
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

        sessionStore.upsertUsers(fetchedUsers)
    }

    // MARK: - Update Read Date

    func updateReadDate(
        for messages: [Message]
    ) async throws(Exception) -> Conversation {
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

        let readReceipt = ReadReceipt(userID: currentUserID, readDate: .now)
        let unreadMessages = messages.filter { $0.currentUserReadReceipt == nil }

        var modifiedMessages = self.messages ?? []
        for unreadMessage in unreadMessages {
            var readReceipts = unreadMessage.readReceipts?.filter { $0.userID != currentUserID } ?? []
            readReceipts.append(readReceipt)

            let readMessage = try await unreadMessage.update(
                \.readReceipts,
                to: readReceipts.unique
            )

            if let unreadMessageIndex = modifiedMessages.firstIndex(where: {
                $0.id == readMessage.id
            }) {
                modifiedMessages.remove(at: unreadMessageIndex)
                modifiedMessages.insert(
                    readMessage,
                    at: unreadMessageIndex
                )
            } else {
                modifiedMessages.append(readMessage)
            }
        }

        guard modifiedMessages.count == (self.messages ?? []).count else {
            throw Exception(
                "Mismatched ratio returned.",
                metadata: .init(sender: self)
            )
        }

        Logger.log(
            "Updated read date for \(unreadMessages.count) message\(unreadMessages.count == 1 ? "" : "s").",
            domain: .conversation,
            sender: self
        )

        // TODO: Should be removed once a proper fix is found.
        RuntimeStorage.store(
            id.key,
            as: .updatedReadReceipts
        )

        return try await update(
            \.messages,
            to: modifiedMessages
        )
    }

    // MARK: - Hashable Conformance

    func hash(into hasher: inout Hasher) {
        hasher.combine(id.key)
        hasher.combine(id.hash)
    }
}
