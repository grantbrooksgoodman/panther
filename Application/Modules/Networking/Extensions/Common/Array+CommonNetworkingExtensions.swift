//
//  Array+CommonNetworkingExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public extension Array where Element == Conversation {
    // MARK: - Properties

    var filteringBlockedUsers: [Conversation] {
        @Dependency(\.clientSession.user.currentUser?.blockedUserIDs) var blockedUserIDs: [String]?
        guard let blockedUserIDs else { return self }
        return filter { !blockedUserIDs.containsAnyString(in: $0.participants.map(\.userID)) }
    }

    var sortedByLatestMessageSentDate: [Conversation] {
        guard allSatisfy({ $0.messages != nil }) else { return self }
        return sorted(by: { $0.messages!
                .sorted(by: { $0.sentDate > $1.sentDate })
                .first!.sentDate >
                $1.messages!
                .sorted(by: { $0.sentDate > $1.sentDate })
                .first!.sentDate
        })
    }

    var uniquedByIDKey: [Conversation] {
        var conversations = [Conversation]()

        for conversation in self where !conversations.contains(where: { $0.id.key == conversation.id.key }) {
            conversations.append(conversation)
        }

        return conversations
    }

    /// The conversations among the array in which the current user is participating, has not deleted, and which do not contain any participants which the user has blocked.
    var visibleForCurrentUser: [Conversation] {
        @Persistent(.currentUserID) var currentUserID: String?
        guard let currentUserID else { return self }

        func satisfiesConstraints(_ conversation: Conversation) -> Bool {
            guard let participant = conversation.participants.first(where: { $0.userID == currentUserID }) else { return false }
            return !participant.hasDeletedConversation
        }

        return filter { satisfiesConstraints($0) }.filteringBlockedUsers
    }

    // MARK: - Methods

    @discardableResult
    func setMessages() async -> Exception? {
        for conversation in self {
            if let exception = await conversation.setMessages() {
                return exception
            }
        }

        return nil
    }

    @discardableResult
    func setUsers() async -> Exception? {
        for conversation in self {
            if let exception = await conversation.setUsers() {
                return exception
            }
        }

        return nil
    }
}

public extension Array where Element == Message {
    /// The unique messages among the array according to their `id` value, where those with populated `readDate` fields take priority.
    var uniquedByID: [Message] {
        let withReadDate = filter { $0.readDate != nil }
        let withoutReadDate = filter { $0.readDate == nil }

        var messages = [Message]()

        for message in withReadDate where !messages.contains(where: { $0.id == message.id }) {
            messages.append(message)
        }

        for message in withoutReadDate where !messages.contains(where: { $0.id == message.id }) {
            messages.append(message)
        }

        return messages
    }
}
