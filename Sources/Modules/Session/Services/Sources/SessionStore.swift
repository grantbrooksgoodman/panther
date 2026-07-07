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

struct SessionStore: @unchecked Sendable {
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
        state.projectedValue.withValue {
            $0.conversations = [:]
        }

        persistConversationArchive()
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
        var shouldLogRemoval = false
        state.projectedValue.withValue {
            shouldLogRemoval = $0.conversations[idKey] != nil
            $0.conversations[idKey] = nil
        }

        persistConversationArchive()
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

    func upsertConversation(_ conversation: Conversation) {
        if conversation.isEmpty ||
            conversation.isMock ||
            conversation.id.hash.isBlank ||
            conversation.id.key.isBlank { return }

        state.projectedValue.withValue {
            $0.conversations[conversation.id.key] = conversation
        }

        persistConversationArchive()
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

        if RuntimeStorage.updatedReadReceipts == conversation.id.key {
            Task { @MainActor in
                redrawConversationsPageView()
            }

            RuntimeStorage.remove(.updatedReadReceipts)
        }
    }

    func upsertConversations(_ newConversations: Set<Conversation>) {
        let newConversations = newConversations.filter {
            !$0.isEmpty &&
                !$0.isMock &&
                !$0.id.hash.isBlank &&
                !$0.id.key.isBlank
        }

        state.projectedValue.withValue {
            for conversation in newConversations {
                $0.conversations[conversation.id.key] = conversation
            }
        }

        persistConversationArchive()
        Logger.log(
            "Added \(newConversations.count) conversations to persisted archive.",
            domain: .conversationArchive,
            sender: self
        )
    }

    // MARK: - Message Methods

    func clearMessageArchive() {
        state.projectedValue.withValue {
            $0.messages = [:]
        }

        persistMessageArchive()
    }

    func upsertMessages(_ newMessages: Set<Message>) {
        let messages = Set(Array(newMessages).filteringSystemMessages)
        state.projectedValue.withValue {
            for message in messages {
                $0.messages[message.id] = message
            }
        }

        persistMessageArchive()
        Logger.log(
            "Added \(messages.count) messages to persisted archive.",
            domain: .messageArchive,
            sender: self
        )
    }

    // MARK: - User Methods

    func upsertUser(_ user: User) {
        state.projectedValue.withValue { $0.users[user.id] = user }
    }

    func upsertUsers(_ newUsers: Set<User>) {
        state.projectedValue.withValue {
            for user in newUsers {
                $0.users[user.id] = user
            }
        }
    }

    // MARK: - Auxiliary

    private func persistConversationArchive() {
        let snapshot = Set(state.wrappedValue.conversations.values)
        persistedConversationArchive = snapshot.isEmpty ? nil : snapshot
        persistValuesForNotificationExtension(snapshot)
    }

    private func persistMessageArchive() {
        let snapshot = Set(state.wrappedValue.messages.values)
        persistedMessageArchive = snapshot.isEmpty ? nil : snapshot
    }

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

    @MainActor // FIXME: This is a band-aid fix (and not a reliable one) for a problem that shouldn't exist.
    private func redrawConversationsPageView() {
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
