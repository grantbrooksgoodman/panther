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

// TODO: Make this operate on Sets instead of Arrays.
struct SessionStore {
    // MARK: - Types

    private struct State {
        var conversations: [String: Conversation] = [:]
        var messages: [String: Message] = [:]
        var users: [String: User] = [:]
    }

    // MARK: - Dependencies

    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Properties

    static let shared = SessionStore()

    private let state = LockIsolated(State())

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
        @Persistent(.conversationArchive) var conversationArchive: [Conversation]?
        @Persistent(.messageArchive) var messageArchive: [Message]?

        if let conversationArchive {
            upsertConversations(conversationArchive)
            Logger.log(
                "Loaded \(conversationArchive.count) conversations into memory.",
                domain: .sessionStore,
                sender: self
            )
        }

        if let messageArchive {
            upsertMessages(messageArchive)
            Logger.log(
                "Loaded \(messageArchive.count) messages into memory.",
                domain: .sessionStore,
                sender: self
            )
        }
    }

    // MARK: - Conversation Methods

    func upsertConversation(_ conversation: Conversation) {
        if conversation.isEmpty ||
            conversation.isMock ||
            conversation.id.hash.isBlank ||
            conversation.id.key.isBlank { return }

        state.projectedValue.withValue {
            $0.conversations[conversation.id.key] = conversation
        }

        networking.conversationService.archive.addValue(conversation)
        if RuntimeStorage.updatedReadReceipts == conversation.id.key {
            Task { @MainActor in
                redrawConversationsPageView()
            }

            RuntimeStorage.remove(.updatedReadReceipts)
        }
    }

    func upsertConversations(_ newConversations: [Conversation]) {
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

        networking.conversationService.archive.addValues(
            Set(newConversations)
        )
    }

    // MARK: - Message Methods

    func upsertMessages(_ newMessages: [Message]) {
        let messages = newMessages.filteringSystemMessages
        state.projectedValue.withValue {
            for message in messages {
                $0.messages[message.id] = message
            }
        }

        networking.messageService.archive.addValues(
            Set(messages)
        )
    }

    // MARK: - User Methods

    func upsertUser(_ user: User) {
        state.projectedValue.withValue { $0.users[user.id] = user }
    }

    func upsertUsers(_ newUsers: [User]) {
        state.projectedValue.withValue {
            for user in newUsers {
                $0.users[user.id] = user
            }
        }
    }

    // MARK: - Auxiliary

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
