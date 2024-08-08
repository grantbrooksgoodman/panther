//
//  Conversation.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public final class Conversation: Codable, EncodedHashable, Equatable, Hashable {
    // MARK: - Properties

    // Array
    public let participants: [Participant]
    public let messageIDs: [String]

    /// - Note: Will have an initial value of `nil` if the conversation does not include the current user.
    public private(set) var messages: [Message]?
    /// When set, contains all users participating in this conversation, other than the current user.
    public private(set) var users: [User]?

    // Other
    public let id: ConversationID
    public let metadata: ConversationMetadata

    // MARK: - Computed Properties

    public var hashFactors: [String] {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        var factors = [id.key]
        factors.append(metadata.name)
        factors.append(metadata.imageData?.base64EncodedString() ?? .bangQualifiedEmpty)
        factors.append(dateFormatter.string(from: metadata.lastModifiedDate))
        factors.append(contentsOf: messageIDs)
        factors.append(contentsOf: messages?.map(\.id) ?? messageIDs)
        factors.append(contentsOf: messages?.map(\.encodedHash) ?? [])
        factors.append(contentsOf: participants.map(\.encoded))
        return factors
    }

    // MARK: - Init

    public init(
        _ id: ConversationID,
        messageIDs: [String],
        messages: [Message]?,
        metadata: ConversationMetadata,
        participants: [Participant],
        users: [User]?
    ) {
        self.id = id
        self.messageIDs = messageIDs
        self.messages = messages
        self.metadata = metadata
        self.participants = participants
        self.users = users
    }

    // MARK: - Set Messages

    /// - Note: This method need only be called for conversations in which the current user is not participating.
    public func setMessages() async -> Exception? {
        @Dependency(\.networking.services.message) var messageService: MessageService

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
        @Dependency(\.clientSession.user) var userSession: UserSessionService

        if !forceUpdate {
            guard users == nil else { return nil }
        }

        let getUsersResult = await userSession.getUsers(conversation: self)

        switch getUsersResult {
        case let .success(users):
            // FIXME: Seeing data races occur here. Fixed using mainQueue.sync for now.
            mainQueue.sync {
                self.users = users
            }

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
            return exception
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

        let readDateString = dateFormatter.string(from: Date())
        let messages = messages.filter { $0.readDate == nil }

        var modifiedMessages = self.messages ?? []

        for message in messages {
            let updateValueResult = await message.updateValue(readDateString, forKey: .readDate)

            switch updateValueResult {
            case let .success(message):
                if let messageIndex = modifiedMessages.firstIndex(where: { $0.id == message.id }) {
                    modifiedMessages.remove(at: messageIndex)
                    modifiedMessages.insert(message, at: messageIndex)
                } else {
                    modifiedMessages.append(message)
                }

            case let .failure(exception):
                return .failure(exception)
            }
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
        let sameUsers = left.users == right.users

        guard sameID,
              sameMessageIDs,
              sameMessages,
              sameMetadata,
              sameParticipants,
              sameUsers else { return false }

        return true
    }

    // MARK: - Hashable Conformance

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id.key)
        hasher.combine(id.hash)
    }
}
