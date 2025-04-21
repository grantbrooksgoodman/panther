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

public final class Conversation: Codable, EncodedHashable, Equatable, Hashable {
    // MARK: - Properties

    // Array
    public let messageIDs: [String]
    public let participants: [Participant]
    public let reactionMetadata: [ReactionMetadata]?

    /// - Note: Will have an initial value of `nil` if the conversation does not include the current user.
    public private(set) var messages: [Message]?
    /// When set, contains all users participating in this conversation, other than the current user.
    public private(set) var users: [User]?

    // Other
    public static let empty: Conversation = .init(
        .init(key: "", hash: ""),
        messageIDs: [],
        messages: nil,
        metadata: .empty(userIDs: []),
        participants: [],
        reactionMetadata: nil,
        users: nil
    )

    public let id: ConversationID
    public let metadata: ConversationMetadata

    // MARK: - Computed Properties

    public var hashFactors: [String] {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        var factors = [id.key]
        factors.append(metadata.name)
        factors.append(metadata.imageData?.base64EncodedString() ?? .bangQualifiedEmpty)
        factors.append(metadata.isPenPalsConversation.description)
        factors.append(contentsOf: metadata.penPalsSharingData.map(\.encoded))
        factors.append(dateFormatter.string(from: metadata.lastModifiedDate))
        factors.append(contentsOf: messageIDs)
        // NIT: Maybe adding the message IDs & hashes explains the (intermittent) mismatch between client and server hash values?
        factors.append(contentsOf: messages?.map(\.id) ?? messageIDs)
        factors.append(contentsOf: messages?.map(\.encodedHash) ?? [])
        factors.append(contentsOf: participants.map(\.encoded))
        factors.append(contentsOf: reactionMetadata?.map(\.encodedHash) ?? [])
        return factors.sorted()
    }

    // MARK: - Init

    public init(
        _ id: ConversationID,
        messageIDs: [String],
        messages: [Message]?,
        metadata: ConversationMetadata,
        participants: [Participant],
        reactionMetadata: [ReactionMetadata]?,
        users: [User]?
    ) {
        self.id = id
        self.messageIDs = messageIDs
        self.messages = messages
        self.metadata = metadata
        self.participants = participants
        self.reactionMetadata = reactionMetadata
        self.users = users
    }

    // MARK: - Set Messages

    /// - Note: This method need only be called for conversations in which the current user is not participating.
    public func setMessages() async -> Exception? {
        @Dependency(\.networking.messageService) var messageService: MessageService

        let getMessagesResult = await messageService.getMessages(ids: messageIDs)

        switch getMessagesResult {
        case let .success(messages):
            guard !messages.isEmpty,
                  messages.count == messageIDs.count else {
                return .init("Mismatched ratio returned.", metadata: [self, #file, #function, #line])
            }

            self.messages = messages

            Logger.log(
                .init(
                    "Set messages on conversation.",
                    extraParams: ["ConversationID": id.encoded],
                    metadata: [self, #file, #function, #line]
                ),
                domain: .conversation
            )

            return nil

        case let .failure(exception):
            return exception
        }
    }

    // MARK: - Set Users

    public func setUsers(forceUpdate: Bool = false) async -> Exception? {
        @Dependency(\.mainQueue) var mainQueue: DispatchQueue
        @Dependency(\.networking) var networking: NetworkServices
        @Dependency(\.clientSession.user) var userSession: UserSessionService

        let commonParams = ["ConversationID": id.encoded]
        if !forceUpdate {
            guard users == nil else { return nil }
        }

        @Persistent(.currentUserID) var currentUserID: String?
        let userIDs = participants.map(\.userID).filter { $0 != currentUserID }
        guard !userIDs.isBangQualifiedEmpty else {
            let exception = Exception("No participants for this conversation.", metadata: [self, #file, #function, #line])
            return exception.appending(extraParams: commonParams)
        }

        let getUsersResult = await networking.userService.getUsers(ids: userIDs)

        switch getUsersResult {
        case let .success(users):
            guard !users.isEmpty,
                  users.count == userIDs.count else {
                let exception = Exception("Mismatched ratio returned.", metadata: [self, #file, #function, #line])
                return exception.appending(extraParams: commonParams)
            }

            // FIXME: Seeing data races occur here. Fixed using mainQueue.sync for now.
            mainQueue.sync { self.users = users }

            Logger.log(
                .init(
                    "Set users on conversation.",
                    extraParams: ["ConversationID": id.encoded],
                    metadata: [self, #file, #function, #line]
                ),
                domain: .conversation
            )

            return nil

        case let .failure(exception):
            return exception.appending(extraParams: commonParams)
        }
    }

    // MARK: - Update Read Date

    public func updateReadDate(for messages: [Message]) async -> Callback<Conversation, Exception> {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter

        guard !messages.isEmpty else {
            return .failure(.init(
                "No messages provided.",
                metadata: [self, #file, #function, #line]
            ))
        }

        @Persistent(.currentUserID) var currentUserID: String?
        guard let currentUserID else {
            return .failure(.init(
                "Current user ID has not been set.",
                metadata: [self, #file, #function, #line]
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
                metadata: [self, #file, #function, #line]
            ))
        }

        return await updateValue(modifiedMessages, forKey: .messages)
    }

    // MARK: - Equatable Conformance

    public static func == (left: Conversation, right: Conversation) -> Bool {
        let sameID = left.id == right.id
        let sameMessageIDs = left.messageIDs == right.messageIDs
        let sameMessages = left.messages == right.messages
        let sameMetadata = left.metadata == right.metadata
        let sameParticipants = left.participants == right.participants
        let sameReactionMetadata = left.reactionMetadata == right.reactionMetadata
        let sameUsers = left.users == right.users

        guard sameID,
              sameMessageIDs,
              sameMessages,
              sameMetadata,
              sameParticipants,
              sameReactionMetadata,
              sameUsers else { return false }

        return true
    }

    // MARK: - Hashable Conformance

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id.key)
        hasher.combine(id.hash)
    }
}
