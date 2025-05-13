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

    @LockIsolated private var archive = [Conversation]() {
        didSet {
            persistedArchive = archive.isEmpty ? nil : archive
            persistValuesForNotificationExtension()
        }
    }

    @Persistent(.conversationArchive) private var persistedArchive: [Conversation]?

    // MARK: - Init

    public init() { archive = persistedArchive ?? [] }

    // MARK: - Addition

    public func addValue(_ conversation: Conversation) {
        guard !archive.contains(conversation) else { return }
        archive.removeAll(where: { $0.id.key == conversation.id.key })
        archive.append(conversation)

        Logger.log(
            .init(
                "Added conversation to persisted archive.",
                isReportable: false,
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
    }

    public func removeValue(idKey: String) {
        guard archive.contains(where: { $0.id.key == idKey }) else { return }
        archive.removeAll(where: { $0.id.key == idKey })

        Logger.log(
            .init(
                "Removed conversation from persisted archive.",
                isReportable: false,
                extraParams: ["ConversationIDKey": idKey],
                metadata: [self, #file, #function, #line]
            ),
            domain: .conversation
        )
    }

    // MARK: - Retrieval

    public func getValue(id: ConversationID) -> Conversation? {
        archive.first(where: { $0.id == id })
    }

    public func getValue(idKey: String) -> Conversation? {
        archive.first(where: { $0.id.key == idKey })
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
