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

public final class Conversation: Codable, CompressedHashable, Equatable {
    // MARK: - Properties

    // Array
    public let messages: [Message]
    public let participants: [Participant]

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
        factors.append(contentsOf: messages.map(\.id))
        factors.append(contentsOf: messages.map(\.compressedHash))
        factors.append(contentsOf: participants.map(\.encoded))
        return factors
    }

    // MARK: - Init

    public init(
        _ id: ConversationID,
        messages: [Message],
        lastModifiedDate: Date,
        participants: [Participant],
        users: [User]?
    ) {
        self.id = id
        self.messages = messages
        self.lastModifiedDate = lastModifiedDate
        self.participants = participants
        self.users = users
    }

    // MARK: - Set Users

    public func setUsers() async -> Exception? {
        @Dependency(\.clientSessionService.user) var userSession: UserSessionService

        let getUsersResult = await userSession.getUsers(conversation: self)

        switch getUsersResult {
        case let .success(users):
            self.users = users
            return nil

        case let .failure(exception):
            return exception
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
}
