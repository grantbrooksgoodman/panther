//
//  ConversationSyncData.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

struct ConversationSyncData: Hashable, @unchecked Sendable {
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

    // MARK: - Equatable Conformance

    // NIT: Should we be including messages here?
    static func == (
        left: ConversationSyncData,
        right: ConversationSyncData
    ) -> Bool {
        let leftObjectCount = left.newData.count + left.newData.compactMapValues { $0 as? [String: Any] }.count
        let rightObjectCount = right.newData.count + right.newData.compactMapValues { $0 as? [String: Any] }.count

        guard left.conversation == right.conversation,
              leftObjectCount == rightObjectCount else { return false }

        return true
    }

    // MARK: - Hashable Conformance

    // NIT: Should we be including messages here?
    func hash(into hasher: inout Hasher) {
        hasher.combine(conversation)
        hasher.combine(newData.count + newData.compactMapValues { $0 as? [String: Any] }.count)
    }
}
