//
//  SessionStore.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

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

    // MARK: - Dependencies

    @Dependency(\.appGroupDefaults) private var appGroupDefaults: UserDefaults
    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.jsonEncoder) private var jsonEncoder: JSONEncoder

    // MARK: - Properties

    static let shared = SessionStore()

    private let state = LockIsolated(State())

    @Persistent(.conversationArchive) private var persistedConversationArchive: Set<Conversation>?
    @Persistent(.messageArchive) private var persistedMessageArchive: Set<Message>?

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
            Observables.sessionStoreDidChange.value = .conversations(
                upsertedIDKeys: [],
                removedIDKeys: removedIDKeys
            )
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

        Observables.sessionStoreDidChange.value = .conversations(
            upsertedIDKeys: [],
            removedIDKeys: [idKey]
        )
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

        if RuntimeStorage.updatedReadReceipts == conversation.id.key {
            Task { @MainActor in
                redrawConversationsPageView()
            }

            RuntimeStorage.remove(.updatedReadReceipts)
        }

        if didChange {
            Observables.sessionStoreDidChange.value = .conversations(
                upsertedIDKeys: [conversation.id.key],
                removedIDKeys: []
            )
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
            Observables.sessionStoreDidChange.value = .conversations(
                upsertedIDKeys: changedIDKeys,
                removedIDKeys: []
            )
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
            Observables.sessionStoreDidChange.value = .messages(upsertedIDs: clearedIDs)
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
            Observables.sessionStoreDidChange.value = .messages(upsertedIDs: changedIDs)
        }
    }

    // MARK: - User Methods

    func upsertUser(_ user: User) {
        var didChange = false
        state.projectedValue.withValue {
            didChange = $0.users[user.id] != user
            $0.users[user.id] = user
        }

        if didChange {
            Observables.sessionStoreDidChange.value = .users(upsertedIDs: [user.id])
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

        if !changedIDs.isEmpty {
            Observables.sessionStoreDidChange.value = .users(upsertedIDs: changedIDs)
        }
    }
}

// MARK: - Auxiliary

private extension SessionStore {
    func persistConversationArchive() {
        let snapshot = Set(state.wrappedValue.conversations.values)
        persistedConversationArchive = snapshot.isEmpty ? nil : snapshot
        persistValuesForNotificationExtension(snapshot)
    }

    func persistMessageArchive() {
        let snapshot = Set(state.wrappedValue.messages.values)
        persistedMessageArchive = snapshot.isEmpty ? nil : snapshot
    }

    func persistValuesForNotificationExtension(_ values: Set<Conversation>) {
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

    @MainActor // FIXME: This is a band-aid fix (and not a reliable one) for a problem that shouldn't exist.
    func redrawConversationsPageView() {
        @MainActor
        func redraw() {
            coreUtilities.clearCaches([.conversationCellViewData])
            RootWindowScene.traitCollectionChanged()
        }

        redraw()
        chatPageState.addEffectUponIsPresented(
            changedTo: false,
            id: .redrawConversationsPageView
        ) { redraw() }
    }
}
