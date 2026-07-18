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
        @Dependency(\.clientSession) var clientSession: ClientSession
        @Dependency(\.navigation) var navigation: Navigation

        guard let currentConversation = clientSession
            .entity
            .conversation
            .currentConversation else { return }

        // Dismiss the chat page when the current conversation
        // is removed (e.g., deleted remotely by another
        // participant).

        // TODO: This doesn't work. Investigate this path.
        if case let .conversations(_, removedIDKeys) = change,
           removedIDKeys.contains(currentConversation.id.key) {
            navigation.navigate(to: .userContent(.stack([])))
            Toast.show(
                .init(
                    .banner(style: .info),
                    message: "This conversation is no longer available."
                ),
                translating: Toast.TranslationOptionKey.allCases
            )

            return
        }

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
