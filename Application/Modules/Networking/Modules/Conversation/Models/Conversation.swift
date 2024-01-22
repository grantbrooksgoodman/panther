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
import Redux

public final class Conversation: Codable, CompressedHashable, Equatable, Hashable {
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
    public let lastModifiedDate: Date

    // MARK: - Computed Properties

    public var hashFactors: [String] {
        @Dependency(\.standardDateFormatter) var dateFormatter: DateFormatter
        var factors = [id.key]
        factors.append(dateFormatter.string(from: lastModifiedDate))
        factors.append(contentsOf: messages?.map(\.id) ?? messageIDs)
        factors.append(contentsOf: messages?.map(\.compressedHash) ?? [])
        factors.append(contentsOf: participants.map(\.encoded))
        return factors
    }

    // MARK: - Init

    public init(
        _ id: ConversationID,
        messageIDs: [String],
        messages: [Message]?,
        lastModifiedDate: Date,
        participants: [Participant],
        users: [User]?
    ) {
        self.id = id
        self.messageIDs = messageIDs
        self.messages = messages
        self.lastModifiedDate = lastModifiedDate
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
        @Dependency(\.clientSessionService.user) var userSession: UserSessionService

        if users != nil,
           !forceUpdate {
            return nil
        }

        let getUsersResult = await userSession.getUsers(conversation: self)

        switch getUsersResult {
        case let .success(users):
            self.users = users

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

    public func updateReadDate(for message: Message) async -> Callback<Conversation, Exception> {
        @Dependency(\.standardDateFormatter) var dateFormatter: DateFormatter

        guard let messages else {
            return .failure(.init("Messages have not been set.", metadata: [self, #file, #function, #line]))
        }

        guard let messageIndex = messages.firstIndex(where: { $0.id == message.id }) else {
            return .failure(.init(
                "This conversation does not contain the specified message.",
                extraParams: ["MessageID": message.id],
                metadata: [self, #file, #function, #line]
            ))
        }

        let readDateString = dateFormatter.string(from: Date())
        let updateMessageValueResult = await message.updateValue(readDateString, forKey: .readDate)

        switch updateMessageValueResult {
        case let .success(message):
            var updatedMessages = messages.filter { $0.id != message.id }
            updatedMessages.insert(message, at: messageIndex)
            return await updateValue(updatedMessages, forKey: .messages)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    // MARK: - Equatable Conformance

    public static func == (left: Conversation, right: Conversation) -> Bool {
        let sameID = left.id == right.id
        let sameLastModifiedDate = left.lastModifiedDate == right.lastModifiedDate
        let sameMessages = left.messages == right.messages
        let sameParticipants = left.participants == right.participants
        let sameUsers = left.users == right.users

        guard sameID,
              sameLastModifiedDate,
              sameMessages,
              sameParticipants,
              sameUsers else { return false }

        return true
    }

    // MARK: - Hashable Conformance

    public func hash(into hasher: inout Hasher) {
        hasher.combine(hashFactors)
    }
}
