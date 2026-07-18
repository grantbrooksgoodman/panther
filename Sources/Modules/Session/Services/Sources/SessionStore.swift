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

    private struct ArchiveState {
        var isConversationArchiveDirty = false
        var isMessageArchiveDirty = false
        var isUserArchiveDirty = false
    }

    private struct State {
        var conversations: [String: Conversation] = [:]
        var messages: [String: Message] = [:]
        var users: [String: User] = [:]
    }

    // MARK: - Properties

    static let shared = SessionStore()

    private let archiveState = LockIsolated(ArchiveState())
    private let currentEpoch = LockIsolated(UInt64(0))
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
        state.projectedValue.withValue {
            /* TODO: Audit whether this captures changes effectively.
             May be worthwhile just to compare objects and accept duplicate
             logs if it allows us to preserve state integrity.
             */
            if let existingConversation = $0.conversations[conversation.id.key] {
                didChange = !existingConversation.isTypingStatusEqual(
                    to: conversation
                ) || existingConversation.encodedHash != conversation.encodedHash
            } else {
                didChange = true
            }

            $0.conversations[conversation.id.key] = conversation
        }

        persistConversationArchive()
        if didChange {
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
        if !changedIDKeys.isEmpty {
            Logger.log(
                "Added \(changedIDKeys.count) conversations to persisted archive.",
                domain: .conversationStore,
                sender: self
            )

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
        if !changedIDs.isEmpty {
            Logger.log(
                "Added \(changedIDs.count) messages to persisted archive.",
                domain: .messageStore,
                sender: self
            )

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

    // NIT: Unused.
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
        var didChange = false
        state.projectedValue.withValue {
            didChange = $0.users[user.id] != user
            $0.users[user.id] = user
        }

        persistUserArchive()
        if didChange {
            Logger.log(
                .init(
                    "Added user to persisted archive.",
                    isReportable: false,
                    userInfo: ["UserID": user.id],
                    metadata: .init(sender: self)
                ),
                domain: .userStore
            )

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
        if !changedIDs.isEmpty {
            Logger.log(
                "Added \(changedIDs.count) users to persisted archive.",
                domain: .userStore,
                sender: self
            )

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
        let archiveState = archiveState.projectedValue.withValue {
            let currentState = $0
            $0 = ArchiveState()
            return currentState
        }

        if archiveState.isConversationArchiveDirty {
            let conversationsSnapshot = Set(state.wrappedValue.conversations.values)
            persistedConversationArchive = conversationsSnapshot.isEmpty ? nil : conversationsSnapshot
        }

        if archiveState.isMessageArchiveDirty {
            let messagesSnapshot = cappedMessageSnapshot
            persistedMessageArchive = messagesSnapshot.isEmpty ? nil : messagesSnapshot
        }

        if archiveState.isUserArchiveDirty {
            let usersSnapshot = Set(state.wrappedValue.users.values)
            persistedUserArchive = usersSnapshot.isEmpty ? nil : usersSnapshot
        }

        if archiveState.isConversationArchiveDirty ||
            archiveState.isMessageArchiveDirty ||
            archiveState.isUserArchiveDirty {
            Logger.log(
                "Flushed dirty archives synchronously.",
                domain: .conversationStore,
                sender: self
            )
        }
    }

    // MARK: - Staleness

    func clearStaleConversations(idKeys: Set<String>) {
        staleConversationIDKeys.projectedValue.withValue {
            $0.subtract(idKeys)
        }
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
}

private extension Conversation {
    func isTypingStatusEqual(to conversation: Conversation) -> Bool {
        Set(participants.map(\.isTyping)) ==
            Set(conversation.participants.map(\.isTyping))
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

    // MARK: - Properties

    /// Returns the in-memory messages capped to the newest
    /// messages per conversation for persistence.
    private var cappedMessageSnapshot: Set<Message> {
        typealias Floats = AppConstants.CGFloats.SessionStore
        let currentState = state.wrappedValue
        let messages = currentState.messages
        guard !messages.isEmpty else { return [] }

        // Group referenced message IDs by conversation,
        // keeping only the newest per conversation.
        var retainedIDs = Set<String>()
        for conversation in currentState.conversations.values {
            let messageIDs = conversation.messageIDs.filter {
                messages[$0] != nil
            }

            if messageIDs.count <= Floats.messageArchiveCapPerConversation {
                retainedIDs.formUnion(messageIDs)
            } else {
                retainedIDs.formUnion(
                    messageIDs
                        .compactMap { messages[$0] }
                        .sorted { $0.sentDate < $1.sentDate }
                        .suffix(Floats.messageArchiveCapPerConversation)
                        .map(\.id)
                )
            }
        }

        return Set(
            retainedIDs.compactMap { messages[$0] }
        )
    }

    // MARK: - Methods

    private func emitChange(_ change: SessionStoreChange) {
        Observables.sessionStoreDidChange.value = change
        let handlers = Self.changeHandlers.wrappedValue
        guard !handlers.isEmpty else { return }
        Task { @MainActor in
            handlers.values.forEach { $0(change) }
        }
    }

    private func persistConversationArchive() {
        archiveState.projectedValue.withValue { $0.isConversationArchiveDirty = true }
        let currentEpoch = currentEpoch.wrappedValue

        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.persistConversationArchive.rawValue)",
            delay: .milliseconds(250)
        ) {
            guard self.currentEpoch.wrappedValue == currentEpoch else { return }
            archiveState.projectedValue.withValue { $0.isConversationArchiveDirty = false }

            let conversationsSnapshot = Set(state.wrappedValue.conversations.values)
            persistedConversationArchive = conversationsSnapshot.isEmpty ? nil : conversationsSnapshot
        }

        scheduleDeadlineFlush()
    }

    private func persistMessageArchive() {
        archiveState.projectedValue.withValue { $0.isMessageArchiveDirty = true }
        let currentEpoch = currentEpoch.wrappedValue

        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.persistMessageArchive.rawValue)",
            delay: .milliseconds(250)
        ) {
            guard self.currentEpoch.wrappedValue == currentEpoch else { return }
            archiveState.projectedValue.withValue { $0.isMessageArchiveDirty = false }

            let messagesSnapshot = cappedMessageSnapshot
            persistedMessageArchive = messagesSnapshot.isEmpty ? nil : messagesSnapshot
        }

        scheduleDeadlineFlush()
    }

    private func persistUserArchive() {
        archiveState.projectedValue.withValue { $0.isUserArchiveDirty = true }
        let currentEpoch = currentEpoch.wrappedValue

        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.persistUserArchive.rawValue)",
            delay: .milliseconds(250)
        ) {
            guard self.currentEpoch.wrappedValue == currentEpoch else { return }
            archiveState.projectedValue.withValue { $0.isUserArchiveDirty = false }

            let usersSnapshot = Set(state.wrappedValue.users.values)
            persistedUserArchive = usersSnapshot.isEmpty ? nil : usersSnapshot
        }

        scheduleDeadlineFlush()
    }

    // MARK: - Auxiliary

    /// Schedules a forced flush after 1 second under
    /// sustained mutation, guaranteeing that dirty state
    /// reaches disk even when rapid writes keep resetting
    /// the 250 ms debounce.
    private func scheduleDeadlineFlush() {
        let currentEpoch = currentEpoch.wrappedValue

        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.deadlineFlush.rawValue)",
            delay: .seconds(1)
        ) {
            guard self.currentEpoch.wrappedValue == currentEpoch else { return }
            flushNow()
        }
    }

    /// Removes messages from memory whose ID does not appear
    /// in any stored conversation's `messageIDs`.
    private func sweepOrphanedMessages() {
        var orphanCount = 0
        state.projectedValue.withValue {
            let orphanedIDs = Set($0.messages.keys)
                .subtracting(Set(
                    $0.conversations.values.flatMap(\.messageIDs)
                ))

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
