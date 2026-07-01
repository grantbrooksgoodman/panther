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

    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.networking.conversationService.archive) private var conversationArchive: ConversationArchiveService
    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities

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

    private init() {}

    // MARK: - Conversation Methods

    func upsertConversation(_ conversation: Conversation) {
        state.projectedValue.withValue {
            $0.conversations[conversation.id.key] = conversation
        }

        conversationArchive.addValue(conversation)
        if RuntimeStorage.updatedReadReceipts == conversation.id.key {
            Task { @MainActor in
                redrawConversationsPageView()
            }

            RuntimeStorage.remove(.updatedReadReceipts)
        }
    }

    func upsertConversations(_ newConversations: [Conversation]) {
        state.projectedValue.withValue {
            for conversation in newConversations {
                $0.conversations[conversation.id.key] = conversation
            }
        }

        conversationArchive.addValues(Set(newConversations))
    }

    // MARK: - Message Methods

    func upsertMessages(_ newMessages: [Message]) {
        state.projectedValue.withValue {
            for message in newMessages {
                $0.messages[message.id] = message
            }
        }
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
