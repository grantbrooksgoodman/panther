//
//  ConversationSyncData.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A snapshot of a conversation's in-progress synchronization state.
struct ConversationSyncData: @unchecked Sendable {
    // MARK: - Properties

    /// The conversation being synchronized.
    let conversation: Conversation

    /// The messages resolved for the conversation.
    let messages: [Message]

    /// The latest serialized conversation data fetched from the server.
    let newData: [String: Any]

    // MARK: - Init

    /// Creates conversation sync data with the given values.
    ///
    /// - Parameters:
    ///   - conversation: The conversation being synchronized.
    ///   - messages: The messages resolved for the conversation.
    ///   - newData: The latest serialized conversation data fetched from the server.
    init(
        _ conversation: Conversation,
        messages: [Message] = [],
        newData: [String: Any]
    ) {
        self.conversation = conversation.filteringSystemMessages
        self.messages = messages
        self.newData = newData
    }
}
