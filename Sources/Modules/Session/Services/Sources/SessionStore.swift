//
//  SessionStore.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

struct SessionStore {
    // MARK: - Types

    private struct DirtyFlags {
        var conversations = false
        var messages = false
        var users = false
    }

    private struct State {
        var conversations: [String: Conversation] = [:]
        var messages: [String: Message] = [:]
        var users: [String: User] = [:]
    }

    // MARK: - Properties

    static let shared = SessionStore()

    private let currentEpoch = LockIsolated(UInt64(0))
    private let dirtyFlags = LockIsolated(DirtyFlags())
    private let staleConversationIDKeys = LockIsolated(Set<String>())
    private let state = LockIsolated(State())

    @Persistent(.conversationArchive) private var persistedConversationArchive: Set<Conversation>?
    @Persistent(.messageArchive) private var persistedMessageArchive: Set<Message>?
    @Persistent(.userArchive) private var persistedUserArchive: Set<User>?

    // MARK: - Computed Properties

    var conversations: [String: Conversation] {
        state.wrappedValue.conversations
    }

    var messages: [String: Message] {
        state.wrappedValue.messages
    }

    var users: [String: User] {
        state.wrappedValue.users
    }

    // MARK: - Init

    private init() {
        if let archive = persistedConversationArchive {
            state.projectedValue.withValue {
                for conversation in archive where
                    !conversation.isEmpty &&
                    !conversation.isMock &&
                    !conversation.id.hash.isBlank &&
                    !conversation.id.key.isBlank {
                    $0.conversations[conversation.id.key] = conversation
                }
            }

            Logger.log(
                "Loaded \(archive.count) conversations into memory.",
                domain: .conversationStore,
                sender: self
            )
        }

        if let archive = persistedMessageArchive {
            let messages = Set(Array(archive).filteringSystemMessages)
            state.projectedValue.withValue {
                for message in messages {
                    $0.messages[message.id] = message
                }
            }

            Logger.log(
                "Loaded \(archive.count) messages into memory.",
                domain: .messageStore,
                sender: self
            )
        }

        if let archive = persistedUserArchive {
            state.projectedValue.withValue {
                for user in archive where !user.id.isBlank {
                    $0.users[user.id] = user
                }
            }

            Logger.log(
                "Loaded \(archive.count) users into memory.",
                domain: .userStore,
                sender: self
            )
        }

        sweepOrphanedMessages()
    }

    // MARK: - Conversation Methods

    func clearConversationArchive() {
        var removedIDKeys = Set<String>()
        state.projectedValue.withValue {
            removedIDKeys = Set($0.conversations.keys)
            $0.conversations = [:]
        }

        persistConversationArchive()
        if !removedIDKeys.isEmpty {
            emitChange(.conversations(
                upsertedIDKeys: [],
                removedIDKeys: removedIDKeys
            ))
        }
    }

    func getConversation(id: ConversationID) -> Conversation? {
        guard let conversation = state.wrappedValue.conversations[id.key],
              conversation.id == id else { return nil }
        return conversation
    }

    func getConversation(idKey: String) -> Conversation? {
        state.wrappedValue.conversations[idKey]
    }

    func removeConversation(idKey: String) {
        var didRemove = false
        var orphanedMessageIDs = Set<String>()

        state.projectedValue.withValue {
            guard let conversation = $0.conversations[idKey] else { return }
            didRemove = true

            let conversationMessageIDs = Set(conversation.messageIDs)
            $0.conversations[idKey] = nil

            // Determine which message IDs are not referenced
            // by any remaining conversation.
            let allOtherMessageIDs = Set(
                $0.conversations.values.flatMap(\.messageIDs)
            )

            orphanedMessageIDs = conversationMessageIDs
                .subtracting(allOtherMessageIDs)

            for id in orphanedMessageIDs {
                $0.messages[id] = nil
            }
        }

        persistConversationArchive()
        guard didRemove else { return }

        if !orphanedMessageIDs.isEmpty {
            persistMessageArchive()
            emitChange(.messages(
                upsertedIDs: [],
                removedIDs: orphanedMessageIDs
            ))
        }

        Logger.log(
            .init(
                "Removed conversation from persisted archive.",
                isReportable: false,
                userInfo: ["ConversationIDKey": idKey],
                metadata: .init(sender: self)
            ),
            domain: .conversationStore
        )

        emitChange(.conversations(
            upsertedIDKeys: [],
            removedIDKeys: [idKey]
        ))
    }

    func upsertConversation(_ conversation: Conversation) {
        if conversation.isEmpty ||
            conversation.isMock ||
            conversation.id.hash.isBlank ||
            conversation.id.key.isBlank { return }

        var didChange = false
        var didContainValue = false
        state.projectedValue.withValue {
            if let existingConversation = $0.conversations[conversation.id.key] {
                didContainValue = existingConversation.id.hash == conversation.id.hash
                didChange = existingConversation != conversation
            } else {
                didChange = true
            }

            $0.conversations[conversation.id.key] = conversation
        }

        persistConversationArchive()
        if !didContainValue {
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
                domain: .conversationStore
            )
        }

        if didChange {
            emitChange(.conversations(
                upsertedIDKeys: [conversation.id.key],
                removedIDKeys: []
            ))
        }
    }

    func upsertConversations(_ newConversations: Set<Conversation>) {
        let newConversations = newConversations.filter {
            !$0.isEmpty &&
                !$0.isMock &&
                !$0.id.hash.isBlank &&
                !$0.id.key.isBlank
        }

        var changedIDKeys = Set<String>()
        state.projectedValue.withValue {
            for conversation in newConversations {
                if $0.conversations[conversation.id.key] != conversation {
                    changedIDKeys.insert(conversation.id.key)
                }

                $0.conversations[conversation.id.key] = conversation
            }
        }

        persistConversationArchive()
        Logger.log(
            "Added \(newConversations.count) conversations to persisted archive.",
            domain: .conversationStore,
            sender: self
        )

        if !changedIDKeys.isEmpty {
            emitChange(.conversations(
                upsertedIDKeys: changedIDKeys,
                removedIDKeys: []
            ))
        }
    }

    // MARK: - Message Methods

    func clearMessageArchive() {
        var clearedIDs = Set<String>()
        state.projectedValue.withValue {
            clearedIDs = Set($0.messages.keys)
            $0.messages = [:]
        }

        persistMessageArchive()

        if !clearedIDs.isEmpty {
            emitChange(.messages(
                upsertedIDs: [],
                removedIDs: clearedIDs
            ))
        }
    }

    func removeMessages(ids: Set<String>) {
        var removedIDs = Set<String>()
        state.projectedValue.withValue {
            for id in ids where $0.messages[id] != nil {
                $0.messages[id] = nil
                removedIDs.insert(id)
            }
        }

        guard !removedIDs.isEmpty else { return }
        persistMessageArchive()

        Logger.log(
            "Removed \(removedIDs.count) message(s) from persisted archive.",
            domain: .messageStore,
            sender: self
        )

        emitChange(.messages(
            upsertedIDs: [],
            removedIDs: removedIDs
        ))
    }

    func upsertMessages(_ newMessages: Set<Message>) {
        let messages = Set(Array(newMessages).filteringSystemMessages)

        var changedIDs = Set<String>()
        state.projectedValue.withValue {
            for message in messages {
                if $0.messages[message.id] != message {
                    changedIDs.insert(message.id)
                }

                $0.messages[message.id] = message
            }
        }

        persistMessageArchive()
        Logger.log(
            "Added \(messages.count) messages to persisted archive.",
            domain: .messageStore,
            sender: self
        )

        if !changedIDs.isEmpty {
            emitChange(.messages(
                upsertedIDs: changedIDs,
                removedIDs: []
            ))
        }
    }

    // MARK: - User Methods

    func clearUserArchive() {
        var clearedIDs = Set<String>()
        state.projectedValue.withValue {
            clearedIDs = Set($0.users.keys)
            $0.users = [:]
        }

        persistUserArchive()
        if !clearedIDs.isEmpty {
            emitChange(.users(
                upsertedIDs: [],
                removedIDs: clearedIDs
            ))
        }
    }

    func removeUser(id: String) {
        var didRemove = false
        state.projectedValue.withValue {
            didRemove = $0.users[id] != nil
            $0.users[id] = nil
        }

        guard didRemove else { return }
        persistUserArchive()

        Logger.log(
            .init(
                "Removed user from persisted archive.",
                isReportable: false,
                userInfo: ["UserID": id],
                metadata: .init(sender: self)
            ),
            domain: .userStore
        )

        emitChange(.users(
            upsertedIDs: [],
            removedIDs: [id]
        ))
    }

    func upsertUser(_ user: User) {
        var didContainValue = false
        var didChange = false
        state.projectedValue.withValue {
            didContainValue = $0.users[user.id] != nil
            didChange = $0.users[user.id] != user
            $0.users[user.id] = user
        }

        persistUserArchive()
        if !didContainValue {
            Logger.log(
                .init(
                    "Added user to persisted archive.",
                    isReportable: false,
                    userInfo: ["UserID": user.id],
                    metadata: .init(sender: self)
                ),
                domain: .userStore
            )
        }

        if didChange {
            emitChange(.users(
                upsertedIDs: [user.id],
                removedIDs: []
            ))
        }
    }

    func upsertUsers(_ newUsers: Set<User>) {
        var changedIDs = Set<String>()
        state.projectedValue.withValue {
            for user in newUsers {
                if $0.users[user.id] != user {
                    changedIDs.insert(user.id)
                }

                $0.users[user.id] = user
            }
        }

        persistUserArchive()
        Logger.log(
            "Added \(newUsers.count) users to persisted archive.",
            domain: .userStore,
            sender: self
        )

        if !changedIDs.isEmpty {
            emitChange(.users(
                upsertedIDs: changedIDs,
                removedIDs: []
            ))
        }
    }

    // MARK: - Epoch

    /// Advances the epoch counter so that any in-flight
    /// debounced persist tasks scheduled under the previous
    /// epoch will no-op when they fire.
    func advanceEpoch() {
        currentEpoch.projectedValue.withValue { $0 &+= 1 }
    }

    // MARK: - Flush

    /// Synchronously persists all dirty archives, bypassing
    /// the debounced schedule. Call from background-entry
    /// and termination handlers to avoid data loss.
    func flushNow() {
        let flags = dirtyFlags.projectedValue.withValue {
            let current = $0
            $0 = DirtyFlags()
            return current
        }

        if flags.conversations {
            let snapshot = Set(state.wrappedValue.conversations.values)
            persistedConversationArchive = snapshot.isEmpty ? nil : snapshot
        }

        if flags.messages {
            let snapshot = cappedMessageSnapshot()
            persistedMessageArchive = snapshot.isEmpty ? nil : snapshot
        }

        if flags.users {
            let snapshot = Set(state.wrappedValue.users.values)
            persistedUserArchive = snapshot.isEmpty ? nil : snapshot
        }

        if flags.conversations || flags.messages || flags.users {
            Logger.log(
                "Flushed dirty archives synchronously.",
                domain: .conversationStore,
                sender: self
            )
        }
    }

    // MARK: - Staleness

    func clearStaleness(idKeys: Set<String>) {
        staleConversationIDKeys.projectedValue.withValue {
            $0.subtract(idKeys)
        }
    }

    func isConversationStale(idKey: String) -> Bool {
        staleConversationIDKeys.wrappedValue.contains(idKey)
    }

    func markConversationsStale(idKeys: Set<String>) {
        staleConversationIDKeys.projectedValue.withValue {
            $0.formUnion(idKeys)
        }
    }
}

extension SessionStore {
    // MARK: - Properties

    private static let changeHandlers = LockIsolated<[UUID: @MainActor @Sendable (SessionStoreChange) -> Void]>([:])
    private static let _isChangeEmissionSuppressed = LockIsolated(false)

    static var isChangeEmissionSuppressed: Bool {
        _isChangeEmissionSuppressed.wrappedValue
    }

    // MARK: - Methods

    @discardableResult
    static func addChangeHandler(
        _ handler: @escaping @MainActor @Sendable (SessionStoreChange) -> Void
    ) -> UUID {
        let id = UUID()
        changeHandlers.projectedValue.withValue { $0[id] = handler }
        return id
    }

    static func removeChangeHandler(_ id: UUID) {
        changeHandlers.projectedValue.withValue { $0[id] = nil }
    }

    static func setChangeEmissionSuppressed(_ suppressed: Bool) {
        _isChangeEmissionSuppressed.projectedValue.withValue { $0 = suppressed }
    }
}

private extension SessionStore {
    // MARK: - Types

    private enum TaskID: String {
        case deadlineFlush
        case persistConversationArchive
        case persistMessageArchive
        case persistUserArchive
    }

    // MARK: - Methods

    func emitChange(_ change: SessionStoreChange) {
        guard !Self.isChangeEmissionSuppressed else { return }
        Observables.sessionStoreDidChange.value = change
        let handlers = Self.changeHandlers.wrappedValue
        guard !handlers.isEmpty else { return }
        Task { @MainActor in
            for handler in handlers.values {
                handler(change)
            }
        }
    }

    func persistConversationArchive() {
        dirtyFlags.projectedValue.withValue { $0.conversations = true }
        let epoch = currentEpoch.wrappedValue
        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.persistConversationArchive.rawValue)",
            delay: .milliseconds(250)
        ) {
            guard self.currentEpoch.wrappedValue == epoch else { return }
            self.dirtyFlags.projectedValue.withValue { $0.conversations = false }
            let snapshot = Set(self.state.wrappedValue.conversations.values)
            self.persistedConversationArchive = snapshot.isEmpty ? nil : snapshot
        }

        scheduleDeadlineFlush()
    }

    func persistMessageArchive() {
        dirtyFlags.projectedValue.withValue { $0.messages = true }
        let epoch = currentEpoch.wrappedValue
        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.persistMessageArchive.rawValue)",
            delay: .milliseconds(250)
        ) {
            guard self.currentEpoch.wrappedValue == epoch else { return }
            self.dirtyFlags.projectedValue.withValue { $0.messages = false }
            let snapshot = self.cappedMessageSnapshot()
            self.persistedMessageArchive = snapshot.isEmpty ? nil : snapshot
        }

        scheduleDeadlineFlush()
    }

    func persistUserArchive() {
        dirtyFlags.projectedValue.withValue { $0.users = true }
        let epoch = currentEpoch.wrappedValue
        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.persistUserArchive.rawValue)",
            delay: .milliseconds(250)
        ) {
            guard self.currentEpoch.wrappedValue == epoch else { return }
            self.dirtyFlags.projectedValue.withValue { $0.users = false }
            let snapshot = Set(self.state.wrappedValue.users.values)
            self.persistedUserArchive = snapshot.isEmpty ? nil : snapshot
        }

        scheduleDeadlineFlush()
    }

    // MARK: - Auxiliary

    /// Returns the in-memory messages capped to the newest
    /// messages per conversation for persistence.
    func cappedMessageSnapshot() -> Set<Message> {
        typealias Floats = AppConstants.CGFloats.SessionStore
        let currentState = state.wrappedValue
        let allMessages = currentState.messages

        guard !allMessages.isEmpty else { return [] }

        // Group referenced message IDs by conversation,
        // keeping only the newest per conversation.
        var retainedIDs = Set<String>()
        for conversation in currentState.conversations.values {
            let ids = conversation.messageIDs.filter {
                allMessages[$0] != nil
            }

            if ids.count <= Floats.messageArchiveCapPerConversation {
                retainedIDs.formUnion(ids)
            } else {
                let sortedMessages = ids
                    .compactMap { allMessages[$0] }
                    .sorted { $0.sentDate < $1.sentDate }
                    .suffix(Floats.messageArchiveCapPerConversation)

                retainedIDs.formUnion(sortedMessages.map(\.id))
            }
        }

        return Set(
            retainedIDs.compactMap { allMessages[$0] }
        )
    }

    /// Schedules a forced flush after 1 second under
    /// sustained mutation, guaranteeing that dirty state
    /// reaches disk even when rapid writes keep resetting
    /// the 250 ms debounce.
    func scheduleDeadlineFlush() {
        let epoch = currentEpoch.wrappedValue
        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.deadlineFlush.rawValue)",
            delay: .seconds(1)
        ) {
            guard self.currentEpoch.wrappedValue == epoch else { return }
            self.flushNow()
        }
    }

    /// Removes messages from memory whose ID does not appear
    /// in any stored conversation's `messageIDs`.
    func sweepOrphanedMessages() {
        var orphanCount = 0
        state.projectedValue.withValue {
            let referencedIDs = Set(
                $0.conversations.values.flatMap(\.messageIDs)
            )

            let orphanedIDs = Set($0.messages.keys)
                .subtracting(referencedIDs)

            orphanCount = orphanedIDs.count
            for id in orphanedIDs {
                $0.messages[id] = nil
            }
        }

        guard orphanCount > 0 else { return }
        persistMessageArchive()

        Logger.log(
            "Swept \(orphanCount) orphaned message(s) at startup.",
            domain: .messageStore,
            sender: self
        )
    }
}

// swiftlint:enable file_length type_body_length
