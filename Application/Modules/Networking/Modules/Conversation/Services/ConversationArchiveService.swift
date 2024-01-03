//
//  ConversationArchiveService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public final class ConversationArchiveService {
    // MARK: - Properties

    private var archive: [Conversation]?
    @Persistent(.conversationArchive) private var persistedArchive: [Conversation]?

    // MARK: - Init

    public init() {
        archive = persistedArchive
    }

    // MARK: - Addition

    public func addValue(_ conversation: Conversation) {
        var values = archive ?? .init()

        guard !values.contains(conversation) else { return }

        values.removeAll(where: { $0.id.key == conversation.id.key })
        values.append(.init(
            conversation.id,
            messages: conversation.messages,
            lastModifiedDate: conversation.lastModifiedDate,
            participants: conversation.participants,
            users: nil
        ))

        archive = values
        persistedArchive = archive

        Logger.log(
            .init(
                "Added conversation to persisted archive.",
                extraParams: ["ConversationIDKey": conversation.id.key,
                              "ConversationIDHash": conversation.id.hash],
                metadata: [self, #file, #function, #line]
            ),
            domain: .conversation
        )
    }

    // MARK: - Removal

    public func clearArchive() {
        archive = nil
        persistedArchive = nil
    }

    public func removeValue(idKey: String) {
        archive?.removeAll(where: { $0.id.key == idKey })
        persistedArchive = archive
    }

    // MARK: - Retrieval

    public func getValue(id: ConversationID) -> Conversation? {
        archive?.first(where: { $0.id == id })
    }

    public func getValue(idKey: String) -> Conversation? {
        archive?.first(where: { $0.id.key == idKey })
    }
}
