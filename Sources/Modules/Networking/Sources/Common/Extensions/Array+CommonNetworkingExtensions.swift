//
//  Array+CommonNetworkingExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Translator

public extension Array where Element == Conversation {
    // MARK: - Properties

    var sortedByLatestMessageSentDate: [Conversation] {
        let filtered = filter { $0.messages?.isEmpty == false }
        var sorted = filtered.map { conversation in
            (
                conversation,
                conversation
                    .messages!
                    .filteringSystemMessages
                    .max(by: { $0.sentDate < $1.sentDate })!
                    .sentDate
            )
        }.sorted(by: { $0.1 > $1.1 }).map { $0.0 }
        sorted += filter { $0.messages == nil || $0.messages?.isEmpty == true }
        return sorted
    }

    var uniquedByIDKey: [Conversation] {
        var conversations = [Conversation]()

        for conversation in self where !conversations.contains(where: { $0.id.key == conversation.id.key }) {
            conversations.append(conversation)
        }

        return conversations
    }

    /// The conversations among the array in which the current user is participating, has not deleted, and which do not contain any participants the user has blocked.
    var visibleForCurrentUser: [Conversation] {
        filter(\.isVisibleForCurrentUser)
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
    /// The unique messages among the array according to their `id` value, where those with populated `readReceipts` fields take priority.
    var uniquedByID: [Message] {
        let withReadDate = filter { $0.readReceipts != nil }
        let withoutReadDate = filter { $0.readReceipts == nil }

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

public extension Array where Element == String {
    /// An empty array qualified by a single value of "!".
    static var bangQualifiedEmpty: [String] { ["!"] }
    var isBangQualifiedEmpty: Bool { isEmpty || allSatisfy(\.isBangQualifiedEmpty) }
}
