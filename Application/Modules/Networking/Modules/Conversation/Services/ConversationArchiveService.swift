//
//  ConversationArchiveService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import Redux

public final class ConversationArchiveService {
    // MARK: - Dependencies

    @Dependency(\.coreKit.gcd.newSerialQueue) private var serialQueue: DispatchQueue

    // MARK: - Properties

    private let threadLock = NSLock()

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
        values.append(conversation)

        // FIXME: Still seeing data races using mainQueue/serialQueue.sync. Still occur with NSLock, but with less frequency.
        threadLock.lock()
        archive = values
        persistedArchive = archive
        threadLock.unlock()

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
        // FIXME: Still seeing data races using mainQueue/serialQueue.sync. Still occur with NSLock, but with less frequency.
        threadLock.lock()
        archive = nil
        persistedArchive = nil
        threadLock.unlock()
    }

    public func removeValue(idKey: String) {
        guard (archive ?? []).contains(where: { $0.id.key == idKey }) else { return }

        // FIXME: Still seeing data races using mainQueue/serialQueue.sync. Still occur with NSLock, but with less frequency.
        threadLock.lock()
        archive?.removeAll(where: { $0.id.key == idKey })
        persistedArchive = archive
        threadLock.unlock()

        Logger.log(
            .init(
                "Removed conversation from persisted archive.",
                extraParams: ["ConversationIDKey": idKey],
                metadata: [self, #file, #function, #line]
            ),
            domain: .conversation
        )
    }

    // MARK: - Retrieval

    public func getValue(id: ConversationID) -> Conversation? {
        archive?.first(where: { $0.id == id })
    }

    public func getValue(idKey: String) -> Conversation? {
        archive?.first(where: { $0.id.key == idKey })
    }
}
