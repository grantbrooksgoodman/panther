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

@RemotelyUpdatable // swiftlint:disable:next type_body_length
struct Conversation: Codable, EncodedHashable, Hashable {
    // MARK: - Properties

    static let empty: Conversation = .init(
        .init(key: "", hash: ""),
        activities: nil,
        messageIDs: [],
        messages: nil,
        metadata: .empty(userIDs: []),
        participants: [],
        reactionMetadata: nil,
        users: nil
    )

    let activities: [Activity]?
    let id: ConversationID
    let messageIDs: [String]
    let metadata: ConversationMetadata
    let participants: [Participant]
    let reactionMetadata: [ReactionMetadata]?

    /// - Note: Will have an initial value of `nil` if the conversation does not include the current user.
    private(set) var messages: [Message]?
    /// When set, contains all users participating in this conversation, other than the current user.
    private(set) var users: [User]?

    // MARK: - Computed Properties

    var hashFactors: [String] {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        let nonSystemMessages = messages?.filteringSystemMessages
        var factors = [id.key]
        factors.append(contentsOf: activities?.map(\.encodedHash) ?? [])
        factors.append(contentsOf: messageIDs.filter { $0.hasPrefix("-") })
        // NIT: Maybe adding the message IDs & hashes explains the (intermittent) mismatch between client and server hash values?
        factors.append(contentsOf: nonSystemMessages?.map(\.id) ?? [])
        factors.append(contentsOf: nonSystemMessages?.map(\.encodedHash) ?? [])
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

    // MARK: - Init

    init(
        _ id: ConversationID,
        activities: [Activity]?,
        messageIDs: [String],
        messages: [Message]?,
        metadata: ConversationMetadata,
        participants: [Participant],
        reactionMetadata: [ReactionMetadata]?,
        users: [User]?
    ) {
        self.id = id
        self.activities = activities
        self.messageIDs = messageIDs
        self.messages = messages
        self.metadata = metadata
        self.participants = participants
        self.reactionMetadata = reactionMetadata
        self.users = users
    }

    // MARK: - Setting Messages

    /// Returns a copy of this conversation with messages populated.
    ///
    /// - Note: Conventionally, this method need only be called for conversations in which the current user is not participating.
    func settingMessages(ids: Set<String>? = nil) async throws(Exception) -> Conversation {
        @Dependency(\.networking.messageService) var messageService: MessageService

        if let ids {
            var updatedMessages = messages ?? []
            for id in ids {
                let userInfo: [String: Any] = [
                    "ConversationIDKey": self.id.key,
                    "MessageID": id,
                ]

                guard updatedMessages.contains(where: { $0.id == id }) else {
                    throw Exception(
                        "Failed to resolve messages, or no message with the provided ID exists in this conversation.",
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

                guard let messageIndex = updatedMessages.firstIndex(where: {
                    $0.id == id
                }) else {
                    throw Exception(
                        "Failed to resolve messages.",
                        userInfo: userInfo,
                        metadata: .init(sender: self)
                    )
                }

                updatedMessages[messageIndex] = message
            }

            return .init(
                id,
                activities: activities,
                messageIDs: messageIDs,
                messages: updatedMessages,
                metadata: metadata,
                participants: participants,
                reactionMetadata: reactionMetadata,
                users: users
            )
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
                "Set messages on conversation.",
                isReportable: false,
                userInfo: ["ConversationID": id.encoded],
                metadata: .init(sender: self)
            ),
            domain: .conversation
        )

        return .init(
            id,
            activities: activities,
            messageIDs: messageIDs,
            messages: fetchedMessages.hydrated(with: activities),
            metadata: metadata,
            participants: participants,
            reactionMetadata: reactionMetadata,
            users: users
        )
    }

    // MARK: - Setting Users

    /// Returns a copy of this conversation with users populated.
    func settingUsers(forceUpdate: Bool = false) async throws(Exception) -> Conversation {
        @Dependency(\.networking) var networking: NetworkServices

        let userInfo = ["ConversationID": id.encoded]
        if forceUpdate {
            networking.database.setGlobalCacheStrategy(.disregardCache)
        } else {
            guard users == nil else { return self }
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
                "Set users on conversation.",
                isReportable: false,
                userInfo: ["ConversationID": id.encoded],
                metadata: .init(sender: self)
            ),
            domain: .conversation
        )

        return .init(
            id,
            activities: activities,
            messageIDs: messageIDs,
            messages: messages,
            metadata: metadata,
            participants: participants,
            reactionMetadata: reactionMetadata,
            users: fetchedUsers
        )
    }

    // MARK: - Update Read Date

    func updateReadDate(
        for messages: [Message]
    ) async throws(Exception) -> Conversation {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter

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

        return try await update(
            \.messages,
            to: modifiedMessages
        )
    }

    // MARK: - Equatable Conformance

    // NB: Ordered cheapest-to-compare first so the guard short-circuits
    // before reaching expensive array comparisons.
    static func == (
        left: Conversation,
        right: Conversation
    ) -> Bool {
        guard left.id == right.id,
              left.messageIDs == right.messageIDs,
              left.metadata == right.metadata,
              left.participants == right.participants,
              left.activities == right.activities,
              left.reactionMetadata == right.reactionMetadata,
              left.messages == right.messages,
              left.users == right.users else { return false }

        return true
    }

    // MARK: - Hashable Conformance

    func hash(into hasher: inout Hasher) {
        hasher.combine(id.key)
        hasher.combine(id.hash)
    }
}
