//
//  MessageArchiveService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

final class MessageArchiveService: @unchecked Sendable {
    // MARK: - Properties

    @LockIsolated private var archive = Set<Message>()
    @Persistent(.messageArchive) private var persistedArchive: Set<Message>?

    // MARK: - Init

    init() {
        archive = persistedArchive ?? []
    }

    // MARK: - Addition

    func addValue(_ message: Message) {
        $archive.withValue { archive in
            archive = archive.filter { $0.id != message.id }
            archive.insert(message)
        }

        persistArchive()
        Logger.log(
            .init(
                "Added message to persisted archive.",
                isReportable: false,
                userInfo: ["MessageID": message.id],
                metadata: .init(sender: self)
            ),
            domain: .messageArchive
        )
    }

    func addValues(_ messages: Set<Message>) {
        let incomingKeys = messages.map(\.id)
        $archive.withValue { archive in
            archive = archive.filter { !incomingKeys.contains($0.id) }
            archive.formUnion(messages)
        }

        persistArchive()
        Logger.log(
            "Added \(messages.count) messages to persisted archive.",
            domain: .messageArchive,
            sender: self
        )
    }

    // MARK: - Removal

    func clearArchive() {
        archive = []
        persistArchive()
    }

    func removeValue(id: String) {
        var shouldLogRemoval = false
        $archive.withValue { archive in
            shouldLogRemoval = archive.contains(where: { $0.id == id })
            archive = archive.filter { $0.id != id }
        }

        persistArchive()
        guard shouldLogRemoval else { return }
        Logger.log(
            .init(
                "Removed message from persisted archive.",
                isReportable: false,
                userInfo: ["MessageID": id],
                metadata: .init(sender: self)
            ),
            domain: .messageArchive
        )
    }

    // MARK: - Retrieval

    func getValue(id: String) -> Message? {
        $archive.withValue { archive in
            archive.first(where: { $0.id == id })
        }
    }

    // MARK: - Auxiliary

    private func persistArchive() {
        let archiveSnapshot = archive
        persistedArchive = archiveSnapshot.isEmpty ? nil : archiveSnapshot
    }
}
