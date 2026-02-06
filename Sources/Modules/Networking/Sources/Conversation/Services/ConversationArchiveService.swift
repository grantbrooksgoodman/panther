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
final class ConversationArchiveService {
    // MARK: - Dependencies

    @Dependency(\.appGroupDefaults) private var appGroupDefaults: UserDefaults
    @Dependency(\.jsonEncoder) private var jsonEncoder: JSONEncoder
    @Dependency(\.build.loggingEnabled) private var loggingEnabled: Bool

    // MARK: - Properties

    @LockIsolated private var archive = Set<Conversation>() {
        didSet {
            persistedArchive = archive.isEmpty ? nil : archive
            persistValuesForNotificationExtension()
        }
    }

    @Persistent(.conversationArchive) private var persistedArchive: Set<Conversation>?

    // MARK: - Init

    init() { archive = persistedArchive ?? [] }

    // MARK: - Addition

    func addValue(_ conversation: Conversation) {
        archive = archive.filter { $0.id.key != conversation.id.key }
        archive.insert(conversation)

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
            domain: .conversation
        )
    }

    func addValues(_ conversations: Set<Conversation>) {
        let incomingKeys = conversations.map(\.id.key)
        archive = archive.filter { !incomingKeys.contains($0.id.key) }
        archive.formUnion(conversations)

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
                domain: .conversation
            )
        } else {
            Logger.log(
                .init(
                    "Added multiple conversations to persisted archive.",
                    isReportable: false,
                    metadata: .init(sender: self)
                ),
                domain: .conversation
            )
        }
    }

    // MARK: - Removal

    func clearArchive() {
        archive = []
    }

    func removeValue(idKey: String) {
        let shouldLogRemoval = archive.contains(where: { $0.id.key == idKey })
        archive = archive.filter { $0.id.key != idKey }

        guard shouldLogRemoval else { return }
        Logger.log(
            .init(
                "Removed conversation from persisted archive.",
                isReportable: false,
                userInfo: ["ConversationIDKey": idKey],
                metadata: .init(sender: self)
            ),
            domain: .conversation
        )
    }

    // MARK: - Retrieval

    func getValue(id: ConversationID) -> Conversation? {
        archive.first(where: { $0.id == id })
    }

    func getValue(idKey: String) -> Conversation? {
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
            appGroupDefaults.set(
                encoded,
                forKey: NotificationExtensionConstants.conversationNameMapDefaultsKeyName
            )
        }
    }
}
