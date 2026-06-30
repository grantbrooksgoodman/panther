//
//  HydratedConversation.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

struct HydratedConversation: Equatable {
    let conversation: Conversation
    let messages: [Message]
    let users: [User]
}

extension SessionStore {
    func hydrated(_ key: String) -> HydratedConversation? {
        guard let conversation = conversations[key] else { return nil }
        return .init(
            conversation: conversation,
            messages: conversation.messageIDs.compactMap { messages[$0] },
            users: conversation.participants.compactMap { users[$0.userID] }
        )
    }

    func hydratedConversations(for userID: String) -> [HydratedConversation] {
        guard let user = users[userID] else { return [] }
        return (user.conversationIDs ?? []).compactMap { hydrated($0.key) }
    }
}
