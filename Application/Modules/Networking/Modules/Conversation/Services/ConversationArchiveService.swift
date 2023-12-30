//
//  ConversationArchiveService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct ConversationArchiveService {
    // MARK: - Properties

    @Persistent(.conversationArchive) private var persistedArchive: [Conversation]?

    // MARK: - Addition

    public func addValue(_ conversation: Conversation) {
        var values = persistedArchive ?? .init()

        values.removeAll(where: { $0.id.key == conversation.id.key })
        values.append(conversation)
        persistedArchive = values

        Logger.log(
            .init(
                "Added conversation to local archive.",
                extraParams: ["ConversationIDKey": conversation.id.key,
                              "ConversationIDHash": conversation.id.hash],
                metadata: [self, #file, #function, #line]
            ),
            domain: .conversation
        )
    }

    // MARK: - Removal

    public func clearArchive() {
        persistedArchive = nil
    }

    public func removeValue(idKey: String) {
        persistedArchive?.removeAll(where: { $0.id.key == idKey })
    }

    // MARK: - Retrieval

    public func getValue(id: ConversationID) -> Conversation? {
        persistedArchive?.first(where: { $0.id == id })
    }

    public func getValue(idKey: String) -> Conversation? {
        persistedArchive?.first(where: { $0.id.key == idKey })
    }
}
