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
final class ConversationArchiveService: @unchecked Sendable {
    // MARK: - Dependencies

    @Dependency(\.appGroupDefaults) private var appGroupDefaults: UserDefaults
    @Dependency(\.jsonEncoder) private var jsonEncoder: JSONEncoder
    @Dependency(\.build.loggingEnabled) private var loggingEnabled: Bool

    // MARK: - Properties

    @LockIsolated private var archive = Set<Conversation>()
    @Persistent(.conversationArchive) private var persistedArchive: Set<Conversation>?

    // MARK: - Init

    init() { archive = persistedArchive ?? [] }

    // MARK: - Addition

    func addValue(_ conversation: Conversation) {
        $archive.withValue { archive in
            archive = archive.filter { $0.id.key != conversation.id.key }
            archive.insert(conversation)
        }

        persistArchive()
        Logger.log(
            .init(
                "Added conversation to persisted archive.",
                isReportable: false,
                userInfo: [
                    "ConversationIDKey": conversation.id.key,
                    "ConversationIDHash": conversation.id.hash,
                ],
                metadata: .init(sender: self)
            ),
            domain: .conversationArchive
        )
    }

    func addValues(_ conversations: Set<Conversation>) {
        let incomingKeys = conversations.map(\.id.key)
        $archive.withValue { archive in
            archive = archive.filter { !incomingKeys.contains($0.id.key) }
            archive.formUnion(conversations)
        }

        persistArchive()
        if loggingEnabled {
            Logger.log(
                .init(
                    "Added multiple conversations to persisted archive.",
                    isReportable: false,
                    userInfo: conversations.reduce(
                        into: [String: String]()
                    ) { partialResult, conversation in
                        partialResult[conversation.id.key] = conversation.id.hash
                    },
                    metadata: .init(sender: self)
                ),
                domain: .conversationArchive
            )
        } else {
            Logger.log(
                "Added multiple conversations to persisted archive.",
                domain: .conversationArchive,
                sender: self
            )
        }
    }

    // MARK: - Removal

    func clearArchive() {
        archive = []
        persistArchive()
    }

    func removeValue(idKey: String) {
        var shouldLogRemoval = false
        $archive.withValue { archive in
            shouldLogRemoval = archive.contains(where: { $0.id.key == idKey })
            archive = archive.filter { $0.id.key != idKey }
        }

        persistArchive()
        guard shouldLogRemoval else { return }
        Logger.log(
            .init(
                "Removed conversation from persisted archive.",
                isReportable: false,
                userInfo: ["ConversationIDKey": idKey],
                metadata: .init(sender: self)
            ),
            domain: .conversationArchive
        )
    }

    // MARK: - Retrieval

    func getValue(id: ConversationID) -> Conversation? {
        $archive.withValue { archive in
            archive.first(where: { $0.id == id })
        }
    }

    func getValue(idKey: String) -> Conversation? {
        $archive.withValue { archive in
            archive.first(where: { $0.id.key == idKey })
        }
    }

    // MARK: - Persist Values for Notification Extension

    private func persistValuesForNotificationExtension(_ values: Set<Conversation>) {
        Task { @MainActor in
            var conversationNameMap = [String: String]()

            for conversation in values where conversation.participants.count > 2 {
                guard let titleLabelText = ConversationCellViewData(conversation)?.titleLabelText,
                      !titleLabelText.isBangQualifiedEmpty else { continue }
                conversationNameMap[conversation.id.key] = titleLabelText
            }

            guard let encoded = try? jsonEncoder.encode(conversationNameMap) else { return }
            appGroupDefaults.set(
                encoded,
                forKey: NotificationExtensionConstants.conversationNameMapDefaultsKeyName
            )
        }
    }

    // MARK: - Auxiliary

    private func persistArchive() {
        let archiveSnapshot = archive
        persistedArchive = archiveSnapshot.isEmpty ? nil : archiveSnapshot
        persistValuesForNotificationExtension(archiveSnapshot)
    }
}
