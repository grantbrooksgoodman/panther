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

final class Conversation: Codable, EncodedHashable, Hashable {
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
        var factors = [id.key]
        factors.append(contentsOf: activities?.map(\.encodedHash) ?? [])
        factors.append(contentsOf: messageIDs)
        // NIT: Maybe adding the message IDs & hashes explains the (intermittent) mismatch between client and server hash values?
        factors.append(contentsOf: messages?.filteringSystemMessages.map(\.id) ?? [])
        factors.append(contentsOf: messages?.filteringSystemMessages.map(\.encodedHash) ?? [])
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
    func setMessages(ids: Set<String>? = nil) async -> Exception? {
        @Dependency(\.networking.messageService) var messageService: MessageService

        if let ids {
            var exceptions = [Exception]()
            for id in ids {
                if let exception = await updateMessage(id: id) {
                    exceptions.append(exception)
                }
            }
            return exceptions.compiledException
        }

        let messageIDs = filteringSystemMessages.messageIDs
        let getMessagesResult = await messageService.getMessages(ids: messageIDs)

        switch getMessagesResult {
        case let .success(messages):
            guard !messages.isEmpty,
                  messages.count == messageIDs.count else {
                return .init("Mismatched ratio returned.", metadata: .init(sender: self))
            }

            self.messages = messages.hydrated(with: activities)

            Logger.log(
                .init(
                    "Set messages on conversation.",
                    isReportable: false,
                    userInfo: ["ConversationID": id.encoded],
                    metadata: .init(sender: self)
                ),
                domain: .conversation
            )

            return nil

        case let .failure(exception):
            return exception
        }
    }

    private func updateMessage(id: String) async -> Exception? {
        @Dependency(\.networking.messageService) var messageService: MessageService
        let userInfo: [String: Any] = [
            "ConversationIDKey": self.id.key,
            "MessageID": id,
        ]

        guard let messageIndex = messages?.firstIndex(where: { $0.id == id }) else {
            return .init(
                "Failed to resolve messages, or no message with the provided ID exists in this conversation.",
                userInfo: userInfo,
                metadata: .init(sender: self)
            )
        }

        let getMessagesResult = await messageService.getMessage(id: id)

        switch getMessagesResult {
        case let .success(message):
            guard var messages else {
                return .init(
                    "Failed to resolve messages.",
                    userInfo: userInfo,
                    metadata: .init(sender: self)
                )
            }

            messages[messageIndex] = message
            self.messages = messages
            return nil

        case let .failure(exception):
            return exception.appending(userInfo: userInfo)
        }
    }

    // MARK: - Set Users

    func setUsers(forceUpdate: Bool = false) async -> Exception? {
        @Dependency(\.coreKit.gcd) var coreGCD: CoreKit.GCD
        @Dependency(\.networking) var networking: NetworkServices
        @Dependency(\.clientSession.user) var userSession: UserSessionService

        let userInfo = ["ConversationID": id.encoded]
        if !forceUpdate {
            guard users == nil else { return nil }
        }

        let userIDs = participants.map(\.userID).filter { $0 != User.currentUserID }
        guard !userIDs.isBangQualifiedEmpty else {
            let exception = Exception(
                "No participants for this conversation.",
                metadata: .init(sender: self)
            )
            return exception.appending(userInfo: userInfo)
        }

        let getUsersResult = await networking.userService.getUsers(ids: userIDs)

        switch getUsersResult {
        case let .success(users):
            guard !users.isEmpty,
                  users.count == userIDs.count else {
                let exception = Exception("Mismatched ratio returned.", metadata: .init(sender: self))
                return exception.appending(userInfo: userInfo)
            }

            // FIXME: Seeing data races occur here. Fixed using mainQueue.sync for now.
            coreGCD.syncOnMain { self.users = users }

            Logger.log(
                .init(
                    "Set users on conversation.",
                    isReportable: false,
                    userInfo: ["ConversationID": id.encoded],
                    metadata: .init(sender: self)
                ),
                domain: .conversation
            )

            return nil

        case let .failure(exception):
            return exception.appending(userInfo: userInfo)
        }
    }

    // MARK: - Update Read Date

    func updateReadDate(for messages: [Message]) async -> Callback<Conversation, Exception> {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter

        guard !messages.isEmpty else {
            return .failure(.init(
                "No messages provided.",
                metadata: .init(sender: self)
            ))
        }

        guard let currentUserID = User.currentUserID else {
            return .failure(.init(
                "Current user ID has not been set.",
                metadata: .init(sender: self)
            ))
        }

        let readReceipt = ReadReceipt(userID: currentUserID, readDate: .now)
        let unreadMessages = messages.filter { $0.currentUserReadReceipt == nil }

        var modifiedMessages = self.messages ?? []
        for unreadMessage in unreadMessages {
            var readReceipts = unreadMessage.readReceipts?.filter { $0.userID != currentUserID } ?? []
            readReceipts.append(readReceipt)

            let updateValueResult = await unreadMessage.updateValue(readReceipts.unique, forKey: .readReceipts)

            switch updateValueResult {
            case let .success(readMessage):
                if let unreadMessageIndex = modifiedMessages.firstIndex(where: { $0.id == readMessage.id }) {
                    modifiedMessages.remove(at: unreadMessageIndex)
                    modifiedMessages.insert(readMessage, at: unreadMessageIndex)
                } else {
                    modifiedMessages.append(readMessage)
                }

            case let .failure(exception):
                return .failure(exception)
            }
        }

        guard modifiedMessages.count == (self.messages ?? []).count else {
            return .failure(.init(
                "Mismatched ratio returned.",
                metadata: .init(sender: self)
            ))
        }

        return await updateValue(modifiedMessages, forKey: .messages)
    }

    // MARK: - Equatable Conformance

    static func == (left: Conversation, right: Conversation) -> Bool {
        let sameID = left.id == right.id
        let sameActivities = left.activities == right.activities
        let sameMessageIDs = left.messageIDs == right.messageIDs
        let sameMessages = left.messages == right.messages
        let sameMetadata = left.metadata == right.metadata
        let sameParticipants = left.participants == right.participants
        let sameReactionMetadata = left.reactionMetadata == right.reactionMetadata
        let sameUsers = left.users == right.users

        guard sameID,
              sameActivities,
              sameMessageIDs,
              sameMessages,
              sameMetadata,
              sameParticipants,
              sameReactionMetadata,
              sameUsers else { return false }

        return true
    }

    // MARK: - Hashable Conformance

    func hash(into hasher: inout Hasher) {
        hasher.combine(id.key)
        hasher.combine(id.hash)
    }
}
