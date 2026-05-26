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
final class Conversation: Codable, EncodedHashable, Hashable, @unchecked Sendable {
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

    private static let coalescer = KeyedCoalescer<String, Void>()

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

    // MARK: - Set Messages

    /// - Note: Conventionally, this method need only be called for conversations in which the current user is not participating.
    func setMessages(ids: Set<String>? = nil) async throws(Exception) {
        let setMessages: @Sendable () async throws(Exception) -> Void = {
            try await self._setMessages(ids: ids)
        }

        return try await Self.coalescer(
            "\(id.key)_MESSAGES",
            setMessages
        )
    }

    private func _setMessages(ids: Set<String>?) async throws(Exception) {
        @Dependency(\.networking.messageService) var messageService: MessageService

        if let ids {
            var exceptions = [Exception]()
            for id in ids {
                do {
                    try await updateMessage(id: id)
                } catch {
                    exceptions.append(error)
                }
            }

            if let exception = exceptions.compiledException {
                throw exception
            }

            return
        }

        let messageIDs = filteringSystemMessages.messageIDs
        let messages = try await messageService.getMessages(
            ids: messageIDs
        )

        guard !messages.isEmpty,
              messages.count == messageIDs.count else {
            throw Exception(
                "Mismatched ratio returned.",
                metadata: .init(sender: self)
            )
        }

        await MainActor.run {
            self.messages = messages.hydrated(with: self.activities)
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
    }

    private func updateMessage(id: String) async throws(Exception) {
        @Dependency(\.networking.messageService) var messageService: MessageService

        let userInfo: [String: Any] = [
            "ConversationIDKey": self.id.key,
            "MessageID": id,
        ]

        guard messages?.contains(where: { $0.id == id }) == true else {
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

        guard var messages,
              let messageIndex = messages.firstIndex(where: { $0.id == id }) else {
            throw Exception(
                "Failed to resolve messages.",
                userInfo: userInfo,
                metadata: .init(sender: self)
            )
        }

        messages[messageIndex] = message // swiftlint:disable:next identifier_name
        let _messages = messages
        await MainActor.run { self.messages = _messages }
    }

    // MARK: - Set Users

    func setUsers(forceUpdate: Bool = false) async throws(Exception) {
        let setUsers: @Sendable () async throws(Exception) -> Void = {
            try await self._setUsers(forceUpdate: forceUpdate)
        }

        try await Self.coalescer(
            "\(id.key)_USERS",
            setUsers
        )
    }

    private func _setUsers(forceUpdate: Bool) async throws(Exception) {
        @Dependency(\.networking) var networking: NetworkServices
        @Dependency(\.clientSession.user) var userSession: UserSessionService

        let userInfo = ["ConversationID": id.encoded]
        if forceUpdate {
            networking.database.setGlobalCacheStrategy(.disregardCache)
        } else {
            guard users == nil else { return }
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

        let users: [User]
        do {
            users = try await networking.userService.getUsers(
                ids: userIDs
            )
        } catch {
            throw error.appending(userInfo: userInfo)
        }

        guard !users.isEmpty,
              users.count == userIDs.count else {
            throw Exception(
                "Mismatched ratio returned.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        await MainActor.run { self.users = users }
        Logger.log(
            .init(
                "Set users on conversation.",
                isReportable: false,
                userInfo: ["ConversationID": id.encoded],
                metadata: .init(sender: self)
            ),
            domain: .conversation
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
    static func == (left: Conversation, right: Conversation) -> Bool {
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
