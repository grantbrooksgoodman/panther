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

struct MessageOutboxService {
    // MARK: - Types

    struct OutboxChange: Equatable {
        let removedIDs: Set<String>
        let upsertedIDs: Set<String>
    }

    private struct ChangeRegistration {
        let handler: @MainActor @Sendable (OutboxChange) -> Void
    }

    // MARK: - Properties

    static let shared = MessageOutboxService()

    private static let changeHandlers = LockIsolated<[UUID: ChangeRegistration]>([:])

    private let entries = LockIsolated<[String: OutboxEntry]>([:])

    @Persistent(.messageOutbox) private var persistedOutbox: [OutboxEntry]?

    // MARK: - Computed Properties

    var allEntries: [OutboxEntry] {
        entries.wrappedValue.values
            .sorted { $0.createdDate < $1.createdDate }
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
                            domain: .messageOutbox,
                            sender: self
                        )
                    }

                    $0[entry.id] = entry
                }
            }

            Logger.log(
                "Loaded \(archive.count) outbox entries into memory.",
                domain: .messageOutbox,
                sender: self
            )
        }

        garbageCollectPayloadFiles()
    }

    // MARK: - Change Handler Methods

    @discardableResult
    static func addChangeHandler(
        _ handler: @escaping @MainActor @Sendable (OutboxChange) -> Void
    ) -> UUID {
        let id = UUID()
        changeHandlers.projectedValue.withValue {
            $0[id] = .init(handler: handler)
        }

        return id
    }

    static func removeChangeHandler(_ id: UUID) {
        changeHandlers.projectedValue.withValue { $0[id] = nil }
    }

    // MARK: - Query Methods

    func entries(forConversationIDKey conversationIDKey: String) -> [OutboxEntry] {
        entries.wrappedValue.values
            .filter { $0.conversationIDKey == conversationIDKey }
            .sorted { $0.createdDate < $1.createdDate }
    }

    func entry(forID id: String) -> OutboxEntry? {
        entries.wrappedValue[id]
    }

    // MARK: - Mutation Methods

    func enqueue(_ entry: OutboxEntry) {
        entries.projectedValue.withValue { $0[entry.id] = entry }
        persist()

        Logger.log(
            "Enqueued outbox entry \(entry.id) for conversation \(entry.conversationIDKey).",
            domain: .messageOutbox,
            sender: self
        )

        emitChange(.init(
            removedIDs: [],
            upsertedIDs: [entry.id]
        ))
    }

    func markFailed(id: String) {
        guard var entry = entries.wrappedValue[id] else { return }
        entry.state = .failed
        entries.projectedValue.withValue { $0[id] = entry }
        persist()

        Logger.log(
            "Marked outbox entry \(id) as failed (attempt \(entry.attemptCount)).",
            domain: .messageOutbox,
            sender: self
        )

        emitChange(.init(
            removedIDs: [],
            upsertedIDs: [id]
        ))
    }

    func markSending(id: String) {
        guard var entry = entries.wrappedValue[id] else { return }
        entry.state = .sending
        entry.attemptCount += 1
        entry.lastAttemptDate = .now
        entries.projectedValue.withValue { $0[id] = entry }
        persist()

        Logger.log(
            "Marked outbox entry \(id) as sending (attempt \(entry.attemptCount)).",
            domain: .messageOutbox,
            sender: self
        )

        emitChange(.init(
            removedIDs: [],
            upsertedIDs: [id]
        ))
    }

    func remove(id: String) {
        guard let entry = entries.wrappedValue[id] else { return }
        removePayloadFile(for: entry)
        entries.projectedValue.withValue { $0[id] = nil }
        persist()

        Logger.log(
            "Removed outbox entry \(id).",
            domain: .messageOutbox,
            sender: self
        )

        emitChange(.init(
            removedIDs: [id],
            upsertedIDs: []
        ))
    }

    func removeAll() {
        let currentEntries = entries.wrappedValue
        guard !currentEntries.isEmpty else { return }

        let removedIDs = Set(currentEntries.keys)
        for entry in currentEntries.values {
            removePayloadFile(for: entry)
        }

        entries.projectedValue.withValue { $0 = [:] }
        persist()

        Logger.log(
            "Removed all outbox entries (\(removedIDs.count)).",
            domain: .messageOutbox,
            sender: self
        )

        emitChange(.init(
            removedIDs: removedIDs,
            upsertedIDs: []
        ))
    }

    // MARK: - Payload Directory Methods

    /// Copies the file at the given URL into the outbox payload
    /// directory and returns the destination file name.
    func storePayloadFile(from sourceURL: URL) throws -> String {
        @Dependency(\.fileManager) var fileManager: FileManager
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
            domain: .messageOutbox,
            sender: self
        )

        return fileName
    }

    func payloadFileURL(forFileName fileName: String) -> URL {
        payloadDirectoryURL.appending(path: fileName)
    }

    // MARK: - Auxiliary

    private var payloadDirectoryURL: URL {
        @Dependency(\.fileManager) var fileManager: FileManager
        return fileManager.documentsDirectoryURL.appending(path: "outbox")
    }

    private func emitChange(_ change: OutboxChange) {
        let matchingHandlers = Self.changeHandlers.wrappedValue.values
        guard !matchingHandlers.isEmpty else {
            return Logger.log(
                "Skipping outbox change emission. Nobody is listening.",
                domain: .messageOutbox,
                sender: self
            )
        }

        Task { @MainActor in
            matchingHandlers.forEach { $0.handler(change) }
        }
    }

    private func garbageCollectPayloadFiles() {
        @Dependency(\.fileManager) var fileManager: FileManager
        let directory = payloadDirectoryURL

        guard let fileNames = try? fileManager.contentsOfDirectory(atPath: directory.path()) else { return }
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
                domain: .messageOutbox,
                sender: self
            )
        }
    }

    private func persist() {
        persistedOutbox = Array(entries.wrappedValue.values)
    }

    private func removePayloadFile(for entry: OutboxEntry) {
        @Dependency(\.fileManager) var fileManager: FileManager
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
            domain: .messageOutbox,
            sender: self
        )
    }
}
