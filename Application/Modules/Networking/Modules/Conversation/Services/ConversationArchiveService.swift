//
//  ConversationArchiveService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

// FIXME: Previously saw data races using mainQueue/serialQueue.sync. Still occur with NSLock, but with less frequency. Audit new behavior.
public final class ConversationArchiveService {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case archive
        case conversationsForConversationIDKeys
        case conversationsForConversationIDs
    }

    // MARK: - Dependencies

    @Dependency(\.appGroupDefaults) private var appGroupDefaults: UserDefaults
    @Dependency(\.jsonEncoder) private var jsonEncoder: JSONEncoder

    // MARK: - Properties

    // Array
    @Cached(CacheKey.archive) private var cachedArchive: [Conversation]?
    @Persistent(.conversationArchive) private var persistedArchive: [Conversation]?

    // Dictionary
    @Cached(CacheKey.conversationsForConversationIDKeys) private var cachedConversationsForConversationIDKeys: [String: Conversation]?
    @Cached(CacheKey.conversationsForConversationIDs) private var cachedConversationsForConversationIDs: [ConversationID: Conversation]?

    // NSLock
    private let threadLock = NSLock()

    // MARK: - Computed Properties

    private var archive: [Conversation] {
        get { cachedArchive ?? persistedArchive ?? [] }

        set {
            threadLock.lock()
            cachedArchive = newValue
            persistedArchive = newValue
            persistValuesForNotificationExtension()
            threadLock.unlock()
        }
    }

    // MARK: - Addition

    public func addValue(_ conversation: Conversation) {
        var values = archive

        guard !values.contains(conversation) else { return }
        values.removeAll(where: { $0.id.key == conversation.id.key })
        values.append(conversation)

        archive = values
        cachedConversationsForConversationIDKeys = cachedConversationsForConversationIDKeys?.filter { $0.value == conversation }
        cachedConversationsForConversationIDs = cachedConversationsForConversationIDs?.filter { $0.value == conversation }

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
        archive = []
        cachedConversationsForConversationIDKeys = nil
        cachedConversationsForConversationIDs = nil
    }

    public func removeValue(idKey: String) {
        guard archive.contains(where: { $0.id.key == idKey }) else { return }
        archive.removeAll(where: { $0.id.key == idKey })
        cachedConversationsForConversationIDKeys = cachedConversationsForConversationIDKeys?.filter { $0.value.id.key != idKey }
        cachedConversationsForConversationIDs = cachedConversationsForConversationIDs?.filter { $0.value.id.key != idKey }

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
        if let cachedConversationsForConversationIDs,
           let cachedValue = cachedConversationsForConversationIDs[id] {
            return cachedValue
        }

        guard let valueForConversationID = archive.first(where: { $0.id == id }) else { return nil }

        var newCacheValue = cachedConversationsForConversationIDs ?? [:]
        newCacheValue[id] = valueForConversationID
        cachedConversationsForConversationIDs = newCacheValue

        return valueForConversationID
    }

    public func getValue(idKey: String) -> Conversation? {
        if let cachedConversationsForConversationIDKeys,
           let cachedValue = cachedConversationsForConversationIDKeys[idKey] {
            return cachedValue
        }

        guard let valueForConversationIDKey = archive.first(where: { $0.id.key == idKey }) else { return nil }

        var newCacheValue = cachedConversationsForConversationIDKeys ?? [:]
        newCacheValue[idKey] = valueForConversationIDKey
        cachedConversationsForConversationIDKeys = newCacheValue

        return valueForConversationIDKey
    }

    // MARK: - Persist Values for Notification Extension

    private func persistValuesForNotificationExtension() {
        Task { @MainActor in
            var conversationNameMap = [String: String]()

            for conversation in archive where !conversation.metadata.name.isBangQualifiedEmpty {
                conversationNameMap[conversation.id.key] = conversation.metadata.name
            }

            guard let encoded = try? jsonEncoder.encode(conversationNameMap) else { return }
            appGroupDefaults.set(encoded, forKey: NotificationExtensionConstants.conversationNameMapDefaultsKeyName)
        }
    }
}
