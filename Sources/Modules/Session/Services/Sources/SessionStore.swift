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

actor SessionStore {
    // MARK: - Dependencies

    @Dependency(\.networking.conversationService.archive) private var conversationArchive: ConversationArchiveService

    // MARK: - Properties

    fileprivate static let shared = SessionStore()

    private(set) var conversations: [String: Conversation] = [:]
    private(set) var currentUserID: String?
    private(set) var messages: [String: Message] = [:]
    private(set) var users: [String: User] = [:]

    // MARK: - Computed Properties

    var currentUser: User? {
        guard let currentUserID else { return nil }
        return users[currentUserID]
    }

    // MARK: - Init

    private init() {}

    // MARK: - Conversation Methods

    func removeConversation(key: String) {
        conversations.removeValue(forKey: key)
    }

    func upsertConversation(_ conversation: Conversation) {
        conversations[conversation.id.key] = conversation
        conversationArchive.addValue(conversation)
    }

    func upsertConversations(_ newConversations: [Conversation]) {
        for conversation in newConversations {
            conversations[conversation.id.key] = conversation
        }

        conversationArchive.addValues(Set(newConversations))
    }

    // MARK: - Message Methods

    func upsertMessages(_ newMessages: [Message]) {
        for message in newMessages {
            messages[message.id] = message
        }
    }

    // MARK: - User Methods

    func removeUser(id: String) {
        users.removeValue(forKey: id)
    }

    func setCurrentUserID(_ id: String?) {
        currentUserID = id
    }

    func upsertUser(_ user: User) {
        users[user.id] = user
    }

    func upsertUsers(_ newUsers: [User]) {
        for user in newUsers {
            users[user.id] = user
        }
    }
}

private enum SessionStoreDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> SessionStore {
        .shared
    }
}

extension DependencyValues {
    var sessionStore: SessionStore {
        get { self[SessionStoreDependency.self] }
        set { self[SessionStoreDependency.self] = newValue }
    }
}
