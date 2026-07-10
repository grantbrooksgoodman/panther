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

    private struct State {
        var conversations: [String: Conversation] = [:]
        var messages: [String: Message] = [:]
        var users: [String: User] = [:]
    }

    // MARK: - Properties

    static let shared = SessionStore()

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
                domain: .sessionStore,
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
                domain: .sessionStore,
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
                domain: .sessionStore,
                sender: self
            )
        }
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
        state.projectedValue.withValue {
            didRemove = $0.conversations[idKey] != nil
            $0.conversations[idKey] = nil
        }

        persistConversationArchive()
        guard didRemove else { return }
        Logger.log(
            .init(
                "Removed conversation from persisted archive.",
                isReportable: false,
                userInfo: ["ConversationIDKey": idKey],
                metadata: .init(sender: self)
            ),
            domain: .sessionStore
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
                domain: .sessionStore
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
            domain: .sessionStore,
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
            emitChange(.messages(upsertedIDs: clearedIDs))
        }
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
            domain: .sessionStore,
            sender: self
        )

        if !changedIDs.isEmpty {
            emitChange(.messages(upsertedIDs: changedIDs))
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
            emitChange(.users(upsertedIDs: clearedIDs))
        }
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
                domain: .sessionStore
            )
        }

        if didChange {
            emitChange(.users(upsertedIDs: [user.id]))
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
            domain: .sessionStore,
            sender: self
        )

        if !changedIDs.isEmpty {
            emitChange(.users(upsertedIDs: changedIDs))
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

private extension SessionStore {
    // MARK: - Types

    private enum TaskID: String {
        case persistConversationArchive
        case persistMessageArchive
        case persistUserArchive
    }

    // MARK: - Methods

    func emitChange(_ change: SessionStoreChange) {
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
        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.persistConversationArchive.rawValue)",
            delay: .milliseconds(250)
        ) {
            let snapshot = Set(state.wrappedValue.conversations.values)
            persistedConversationArchive = snapshot.isEmpty ? nil : snapshot
        }
    }

    func persistMessageArchive() {
        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.persistMessageArchive.rawValue)",
            delay: .milliseconds(250)
        ) {
            let snapshot = Set(state.wrappedValue.messages.values)
            persistedMessageArchive = snapshot.isEmpty ? nil : snapshot
        }
    }

    func persistUserArchive() {
        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.persistUserArchive.rawValue)",
            delay: .milliseconds(250)
        ) {
            let snapshot = Set(state.wrappedValue.users.values)
            persistedUserArchive = snapshot.isEmpty ? nil : snapshot
        }
    }
}

// swiftlint:enable file_length type_body_length
