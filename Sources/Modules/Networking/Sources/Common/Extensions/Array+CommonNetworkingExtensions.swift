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

extension [Conversation] {
    // MARK: - Properties

    var sortedByLatestMessageSentDate: [Conversation] {
        var withSentDate: [(Conversation, Date)] = []
        var withoutSentDate: [Conversation] = []

        for conversation in self {
            let filteringSystemMessages = conversation.filteringSystemMessages
            guard let messages = filteringSystemMessages.messages,
                  !messages.isEmpty,
                  let latestMessage = messages.max(by: {
                      $0.sentDate < $1.sentDate
                  }) else {
                withoutSentDate.append(conversation)
                continue
            }

            withSentDate.append((
                conversation,
                latestMessage.sentDate
            ))
        }

        return withSentDate
            .sorted { left, right in
                if left.1 != right.1 { return left.1 > right.1 }
                return left.0.id.key < right.0.id.key
            }
            .map(\.0) + withoutSentDate
    }

    /// The conversations among the array in which the current user is participating, has not deleted, and which do not contain any participants the user has blocked.
    var visibleForCurrentUser: [Conversation] {
        filter(\.isVisibleForCurrentUser)
    }

    // MARK: - Methods

    @discardableResult
    func setMessages() async -> Exception? {
        await parallelMap { await $0.setMessages() }
    }

    @discardableResult
    func setUsers() async -> Exception? {
        await parallelMap { await $0.setUsers() }
    }
}

extension [Message] {
    /// The unique messages among the array according to their `id` value, where those with populated `readReceipts` fields take priority.
    var uniquedByID: [Message] {
        var messages = [Message]()
        var seenIDs = Set<String>()

        for message in self where message.readReceipts != nil {
            guard seenIDs.insert(message.id).inserted else { continue }
            messages.append(message)
        }

        for message in self where message.readReceipts == nil {
            guard seenIDs.insert(message.id).inserted else { continue }
            messages.append(message)
        }

        return messages
    }
}
