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
import Redux

public extension Array where Element == Conversation {
    // MARK: - Properties

    var uniquedByIDKey: [Conversation] {
        var conversations = [Conversation]()

        for conversation in self where !conversations.contains(where: { $0.id.key == conversation.id.key }) {
            conversations.append(conversation)
        }

        return conversations
    }

    /// The conversations among the array in which the current user is participating and has not deleted.
    var visibleForCurrentUser: [Conversation] {
        @Persistent(.currentUserID) var currentUserID: UserID?
        guard let currentUserID else { return self }

        func satisfiesConstraints(_ conversation: Conversation) -> Bool {
            let currentUserParticipants = conversation.participants.filter { $0.userIDKey == currentUserID.key }
            guard !currentUserParticipants.isEmpty else { return false }
            return currentUserParticipants.allSatisfy { !$0.hasDeletedConversation }
        }

        return filter { satisfiesConstraints($0) }
    }

    // MARK: - Methods

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
