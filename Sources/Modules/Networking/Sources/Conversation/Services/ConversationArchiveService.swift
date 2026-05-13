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

/* NIT: Debouncing seems broadly effective, but should really be reducing
 the duplicate/unnecessary calls to addValue(_:)/addValues(_:).
 */
final class ConversationArchiveService: @unchecked Sendable {
    // MARK: - Dependencies

    @Dependency(\.appGroupDefaults) private var appGroupDefaults: UserDefaults
    @Dependency(\.jsonEncoder) private var jsonEncoder: JSONEncoder

    // MARK: - Properties

    @LockIsolated private var archive = Set<Conversation>()
    @Persistent(.conversationArchive) private var persistedArchive: Set<Conversation>?

    // MARK: - Init

    init() { archive = persistedArchive ?? [] }

    // MARK: - Addition

    func addValue(_ conversation: Conversation) {
        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(conversation.id.encoded)",
            delay: .milliseconds(10),
        ) { [weak self] in
            guard let self else { return }
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
    }

    func addValues(_ conversations: Set<Conversation>) {
        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(conversations.map(\.id.encoded).joined())",
            delay: .milliseconds(10),
        ) { [weak self] in
            guard let self else { return }
            let incomingKeys = conversations.map(\.id.key)
            $archive.withValue { archive in
                archive = archive.filter { !incomingKeys.contains($0.id.key) }
                archive.formUnion(conversations)
            }

            persistArchive()
            Logger.log(
                "Added \(conversations.count) conversations to persisted archive.",
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
        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(idKey)",
            delay: .milliseconds(10),
        ) { [weak self] in
            guard let self else { return }
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
