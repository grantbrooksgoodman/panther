//
//  ChatPageViewService+SessionStoreChange.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension ChatPageViewService {
    // MARK: - Types

    private enum TaskID: String {
        case chatPageReload
        case navigationTitleRefresh
    }

    // MARK: - Handle Session Store Change

    /// Processes a session store change, reloading the message list when it affects the
    /// displayed conversation.
    ///
    /// A change is relevant when it upserts the displayed conversation, or when it upserts or
    /// removes any of the conversation's messages. Rapid successive changes are debounced into a
    /// single reload. When the change upserts the displayed conversation, the navigation title
    /// is also refreshed from the conversation's latest values, unless the recipient bar is
    /// shown.
    ///
    /// - Parameter change: The session store change to process.
    func handleSessionStoreChange(_ change: SessionStoreChange) {
        @Dependency(\.clientSession.entity.conversation.currentConversation) var currentConversation: Conversation?

        guard let currentConversation else { return }

        let shouldReload: Bool = switch change {
        case let .conversations(upsertedIDKeys, _):
            upsertedIDKeys.contains(currentConversation.id.key)

        case let .messages(upsertedIDs, removedIDs):
            !Set(currentConversation.messageIDs)
                .isDisjoint(with: upsertedIDs.union(removedIDs))

        case .users:
            false
        }

        guard shouldReload else { return }
        debounceReloadCollectionView()

        guard case .conversations = change else { return }
        debounceRefreshNavigationTitle(for: currentConversation)
    }

    // MARK: - Handle Outbox Change

    /// Processes a message outbox change by reloading the message list.
    ///
    /// Rapid successive changes are debounced into a single reload.
    func handleOutboxChange() {
        debounceReloadCollectionView()
    }

    // MARK: - Auxiliary

    private func debounceRefreshNavigationTitle(
        for conversation: Conversation
    ) {
        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.navigationTitleRefresh.rawValue)",
            delay: .milliseconds(250)
        ) { @MainActor [weak self] in
            guard let self,
                  recipientBar?.layout.recipientBarView == nil,
                  let navigationTitle = ConversationCellViewData(
                      conversation,
                      useCachedValue: false
                  )?.titleLabelText else { return }
            setNavigationTitle(navigationTitle)
        }
    }

    private func debounceReloadCollectionView() {
        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.chatPageReload.rawValue)",
            delay: .milliseconds(250)
        ) { @MainActor [weak self] in
            // The current conversation may have been removed from
            // the store between scheduling and firing (e.g., deleted
            // remotely). The chat page is being dismissed, so a
            // reload would size stale messages against no
            // conversation.
            @Dependency(\.clientSession.entity.conversation.currentConversation) var currentConversation: Conversation?
            guard currentConversation != nil else { return }
            self?.reloadCollectionView()
        }
    }
}
