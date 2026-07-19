//
//  ConversationSyncData.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

struct ConversationSyncData: @unchecked Sendable {
    // MARK: - Properties

    let conversation: Conversation
    let messages: [Message]
    let newData: [String: Any]

    // MARK: - Init

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
