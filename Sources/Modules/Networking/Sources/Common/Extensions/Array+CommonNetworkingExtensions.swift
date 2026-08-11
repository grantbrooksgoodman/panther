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
            guard let latestMessageSentDate = conversation.latestMessageSentDate else {
                withoutSentDate.append(conversation)
                continue
            }

            withSentDate.append((
                conversation,
                latestMessageSentDate
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
}

extension [Message] {
    /// The unique messages among the array according to their `id` value,
    /// preserving original order, where those with populated `readReceipts`
    /// fields take priority.
    var uniquedByID: [Message] {
        var indicesForIDs = [String: Int]()
        var uniqueMessages = [Message]()

        for message in self {
            if let index = indicesForIDs[message.id] {
                guard uniqueMessages[index].readReceipts == nil,
                      message.readReceipts != nil else { continue }
                uniqueMessages[index] = message
            } else {
                indicesForIDs[message.id] = uniqueMessages.count
                uniqueMessages.append(message)
            }
        }

        return uniqueMessages
    }
}

private extension Conversation {
    var latestMessageSentDate: Date? {
        [
            // Messages sent before the current user's addition date are hidden
            // from display, so they don't factor into sort order.
            withMessagesOffsetFromCurrentUserAdditionDate
                .filteringSystemMessages
                .messages?
                .map(\.sentDate)
                .max(),
            // Session store does not store system messages; their sent dates resolve from activities.
            activities?
                .filter { $0 != .empty }
                .map(\.date)
                .max(),
        ].compactMap(\.self).max()
    }
}
