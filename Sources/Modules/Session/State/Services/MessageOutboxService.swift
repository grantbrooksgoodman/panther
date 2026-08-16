//
//  MessageOutboxService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// The service that queues messages for delivery and retries failed sends.
///
/// ``MessageOutboxService`` holds pending and failed message entries, persists them to disk, and
/// stores their payload files. It publishes a change whenever its contents change.
struct MessageOutboxService {
    // MARK: - Dependencies

    @Dependency(\.fileManager) private var fileManager: FileManager

    // MARK: - Properties

    /// The shared message outbox service.
    static let shared = MessageOutboxService()

    /// The outbox entries, keyed by identifier.
    let entries = LockIsolated<[String: OutboxEntry]>([:])

    @SharedEvent(\.messageOutboxDidChange) private var messageOutboxDidChange
    @Persistent(.messageOutbox) private var persistedOutbox: [OutboxEntry]?

    // MARK: - Computed Properties

    /// The outbox entries, sorted by creation date.
    var allEntries: [OutboxEntry] {
        entries
            .wrappedValue
            .values
            .sorted { $0.createdDate < $1.createdDate }
    }

    private var payloadDirectoryURL: URL {
        fileManager.documentsDirectoryURL.appending(path: "outbox")
    }

    // MARK: - Init

    private init() {
        if let archive = persistedOutbox {
            entries.projectedValue.withValue {
                for var entry in archive {
                    // Reconcile: any entry still marked .sending
                    // at launch means the app died mid-attempt.
                    if entry.state == .sending {
                        entry.state = .failed

                        Logger.log(
                            "Reconciled stale .sending entry \(entry.id) → .failed.",
                            domain: .outbox,
                            sender: self
                        )
                    }

                    $0[entry.id] = entry
                }
            }

            Logger.log(
                "Loaded \(archive.count) outbox entries into memory.",
                domain: .outbox,
                sender: self
            )
        }

        garbageCollectPayloadFiles()
    }

    // MARK: - Query Methods

    /// Returns the outbox entries for the conversation with the given identifier key, sorted by
    /// creation date.
    ///
    /// - Parameter conversationIDKey: The identifier key of the conversation whose entries to
    ///   return.
    ///
    /// - Returns: The conversation's outbox entries.
    func entries(forConversationIDKey conversationIDKey: String) -> [OutboxEntry] {
        entries.wrappedValue.values
            .filter { $0.conversationIDKey == conversationIDKey }
            .sorted { $0.createdDate < $1.createdDate }
    }

    /// Returns the outbox entry with the given identifier, or `nil` if none exists.
    ///
    /// - Parameter id: The identifier of the entry to return.
    ///
    /// - Returns: The outbox entry, or `nil` if none exists.
    func entry(forID id: String) -> OutboxEntry? {
        entries.wrappedValue[id]
    }

    // MARK: - Mutation Methods

    /// Atomically claims the entry with the given identifier for retry, transitioning it to
    /// `sending`.
    ///
    /// - Parameters:
    ///   - id: The identifier of the entry to claim.
    ///   - candidateRemoteID: The remote identifier to reserve for the entry's message if one is
    ///     not already reserved.
    ///
    /// - Returns: The claimed entry, or `nil` if the entry is missing or already claimed by
    ///   another caller.
    func claimForRetry(
        id: String,
        candidateRemoteID: String
    ) -> OutboxEntry? {
        let claimedEntry: OutboxEntry? = entries
            .projectedValue
            .withValue { entries -> OutboxEntry? in
                guard var entry = entries[id],
                      entry.state != .sending else { return nil }

                if entry.reservedRemoteID == nil {
                    entry.reservedRemoteID = candidateRemoteID
                }

                entry.state = .sending
                entry.attemptCount += 1
                entry.lastAttemptDate = .now

                entries[id] = entry
                return entry
            }

        if let claimedEntry {
            persistArchive()

            Logger.log(
                "Claimed outbox entry \(id) for retry (attempt \(claimedEntry.attemptCount)).",
                domain: .outbox,
                sender: self
            )

            messageOutboxDidChange.send()
        }

        return claimedEntry
    }

    /// Adds the given entry to the outbox.
    ///
    /// - Parameter entry: The entry to add.
    func enqueue(_ entry: OutboxEntry) {
        entries.projectedValue.withValue { $0[entry.id] = entry }
        persistArchive()

        Logger.log(
            "Enqueued outbox entry \(entry.id) for conversation \(entry.conversationIDKey).",
            domain: .outbox,
            sender: self
        )

        messageOutboxDidChange.send()
    }

    /// Marks the outbox entry with the given identifier as failed.
    ///
    /// - Parameter id: The identifier of the entry to mark as failed.
    func markFailed(id: String) {
        guard var entry = entries.wrappedValue[id] else { return }

        entry.state = .failed
        entries.projectedValue.withValue { $0[id] = entry }
        persistArchive()

        Logger.log(
            "Marked outbox entry \(id) as failed (attempt \(entry.attemptCount)).",
            domain: .outbox,
            sender: self
        )

        messageOutboxDidChange.send()
    }

    /// Removes the outbox entry with the given identifier, deleting its payload file.
    ///
    /// - Parameter id: The identifier of the entry to remove.
    func remove(id: String) {
        guard let entry = entries.wrappedValue[id] else { return }

        removePayloadFile(for: entry)
        entries.projectedValue.withValue { $0[id] = nil }
        persistArchive()

        Logger.log(
            "Removed outbox entry \(id).",
            domain: .outbox,
            sender: self
        )

        messageOutboxDidChange.send()
    }

    /// Removes every outbox entry, deleting their payload files.
    func removeAll() {
        let currentEntries = entries.wrappedValue
        guard !currentEntries.isEmpty else { return }

        let removedIDs = Set(currentEntries.keys)
        for entry in currentEntries.values {
            removePayloadFile(for: entry)
        }

        entries.projectedValue.withValue { $0 = [:] }
        persistArchive()

        Logger.log(
            "Removed all outbox entries (\(removedIDs.count)).",
            domain: .outbox,
            sender: self
        )

        messageOutboxDidChange.send()
    }

    // MARK: - Payload Directory Methods

    /// Copies the file at the given URL into the outbox payload directory and returns the
    /// destination file name.
    ///
    /// - Parameter sourceURL: The URL of the file to copy.
    ///
    /// - Returns: The name of the copied file in the payload directory.
    ///
    /// - Throws: An error if the file cannot be copied.
    func storePayloadFile(from sourceURL: URL) throws -> String {
        let directory = payloadDirectoryURL
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let fileName = "\(UUID().uuidString)_\(sourceURL.lastPathComponent)"
        let destinationURL = directory.appending(path: fileName)
        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        Logger.log(
            "Stored payload file \(fileName).",
            domain: .outbox,
            sender: self
        )

        return fileName
    }

    /// Returns the URL of the payload file with the given name.
    ///
    /// - Parameter fileName: The name of the payload file.
    ///
    /// - Returns: The URL of the payload file.
    func payloadFileURL(forFileName fileName: String) -> URL {
        payloadDirectoryURL.appending(path: fileName)
    }

    // MARK: - Auxiliary

    private func garbageCollectPayloadFiles() {
        let directory = payloadDirectoryURL

        guard let fileNames = try? fileManager.contentsOfDirectory(
            atPath: directory.path()
        ) else { return }

        let referencedFileNames = Set(
            entries.wrappedValue.values.compactMap { entry -> String? in
                switch entry.payload {
                case let .audio(inputFileName): return inputFileName
                case let .media(fileName, _): return fileName
                case .text: return nil
                }
            }
        )

        var removedCount = 0
        for fileName in fileNames where !referencedFileNames.contains(fileName) {
            try? fileManager.removeItem(at: directory.appending(path: fileName))
            removedCount += 1
        }

        if removedCount > 0 {
            Logger.log(
                "Garbage-collected \(removedCount) orphaned payload files.",
                domain: .outbox,
                sender: self
            )
        }
    }

    private func persistArchive() {
        persistedOutbox = Array(entries.wrappedValue.values)
    }

    private func removePayloadFile(for entry: OutboxEntry) {
        let fileName: String? = switch entry.payload {
        case let .audio(inputFileName): inputFileName
        case let .media(fileName, _): fileName
        case .text: nil
        }

        guard let fileName else { return }
        let fileURL = payloadDirectoryURL.appending(path: fileName)
        try? fileManager.removeItem(at: fileURL)

        Logger.log(
            "Removed payload file \(fileName) for entry \(entry.id).",
            domain: .outbox,
            sender: self
        )
    }
}
