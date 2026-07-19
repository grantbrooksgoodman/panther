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
    }

    // MARK: - Handle Session Store Change

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
        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.chatPageReload.rawValue)",
            delay: .milliseconds(250)
        ) { @MainActor [weak self] in
            self?.reloadCollectionView()
        }
    }
}
