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
// NIT: Maybe fixed with @LockIsolated?
public final class ConversationArchiveService {
    // MARK: - Dependencies

    @Dependency(\.appGroupDefaults) private var appGroupDefaults: UserDefaults
    @Dependency(\.jsonEncoder) private var jsonEncoder: JSONEncoder

    // MARK: - Properties

    // Array
    @LockIsolated private var archive = [Conversation]() {
        didSet {
            persistedArchive = archive.isEmpty ? nil : archive
            persistValuesForNotificationExtension()
        }
    }

    @Persistent(.conversationArchive) private var persistedArchive: [Conversation]?

    // Dictionary
    @LockIsolated private var conversationsForConversationIDKeys = [String: Conversation]()
    @LockIsolated private var conversationsForConversationIDs = [ConversationID: Conversation]()

    // MARK: - Init

    public init() { archive = persistedArchive ?? [] }

    // MARK: - Addition

    public func addValue(_ conversation: Conversation) {
        guard !archive.contains(conversation) else { return }
        archive.removeAll(where: { $0.id.key == conversation.id.key })
        archive.append(conversation)

        conversationsForConversationIDKeys[conversation.id.key] = conversation
        conversationsForConversationIDs[conversation.id] = conversation

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
        conversationsForConversationIDKeys = [:]
        conversationsForConversationIDs = [:]
    }

    public func removeValue(idKey: String) {
        guard archive.contains(where: { $0.id.key == idKey }) else { return }
        archive.removeAll(where: { $0.id.key == idKey })

        conversationsForConversationIDKeys = conversationsForConversationIDKeys.filter { $0.value.id.key != idKey }
        conversationsForConversationIDs = conversationsForConversationIDs.filter { $0.value.id.key != idKey }

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
        if let value = conversationsForConversationIDs[id] {
            return value
        }

        guard let valueForConversationID = archive.first(where: { $0.id == id }) else { return nil }
        conversationsForConversationIDs[id] = valueForConversationID
        return valueForConversationID
    }

    public func getValue(idKey: String) -> Conversation? {
        if let value = conversationsForConversationIDKeys[idKey] {
            return value
        }

        guard let valueForConversationIDKey = archive.first(where: { $0.id.key == idKey }) else { return nil }
        conversationsForConversationIDKeys[idKey] = valueForConversationIDKey
        return valueForConversationIDKey
    }

    // MARK: - Persist Values for Notification Extension

    private func persistValuesForNotificationExtension() {
        Task { @MainActor in
            var conversationNameMap = [String: String]()

            for conversation in archive where conversation.participants.count > 2 {
                guard let titleLabelText = ConversationCellViewData(conversation)?.titleLabelText,
                      !titleLabelText.isBangQualifiedEmpty else { continue }
                conversationNameMap[conversation.id.key] = titleLabelText
            }

            guard let encoded = try? jsonEncoder.encode(conversationNameMap) else { return }
            appGroupDefaults.set(encoded, forKey: NotificationExtensionConstants.conversationNameMapDefaultsKeyName)
        }
    }
}
