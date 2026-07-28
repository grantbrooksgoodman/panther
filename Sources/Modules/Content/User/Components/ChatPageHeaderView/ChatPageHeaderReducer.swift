//
//  ChatPageHeaderReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 10/07/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

struct ChatPageHeaderReducer: Reducer {
    // MARK: - Types

    private enum TaskID: String {
        case reloadData
    }

    // MARK: - Dependencies

    @Dependency(\.navigation) private var navigation: Navigation

    // MARK: - Actions

    enum Action {
        case backButtonTapped
        case chatInfoButtonTapped
        case reloadData
        case sessionStoreDidChange(SessionStoreChange)
    }

    // MARK: - State

    struct State: Equatable {
        /* MARK: Properties */

        var viewID = UUID()

        /* MARK: Computed Properties */

        @MainActor
        var cellViewData: ConversationCellViewData {
            .init(conversation) ?? .empty
        }

        var conversation: Conversation {
            Dependency(
                \.clientSession.entity.conversation.currentConversation
            ).wrappedValue ?? .empty
        }
    }

    // MARK: - Reduce

    func reduce(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case .backButtonTapped:
            navigation.navigate(to: .userContent(.pop))

        case .chatInfoButtonTapped:
            return .fireAndForget {
                Task { @MainActor in
                    RootSheets.present(.chatInfoPageView)
                }
            }

        case .reloadData:
            state.viewID = UUID()

        case let .sessionStoreDidChange(change):
            guard isRelevantChange(
                change,
                for: state.conversation
            ) else { return .none }

            return .task(delay: .milliseconds(250)) {
                .reloadData
            }
            .cancellable(
                id: "\(String.fromCurrentEditorContext(sender: self))/\(state.conversation.id.key)/\(TaskID.reloadData.rawValue)",
                cancelInFlight: true
            )
        }

        return .none
    }
}

private extension ChatPageHeaderReducer {
    func isRelevantChange(
        _ change: SessionStoreChange,
        for conversation: Conversation
    ) -> Bool {
        switch change {
        case let .conversations(upsertedIDKeys, removedIDKeys):
            upsertedIDKeys.contains(conversation.id.key) ||
                removedIDKeys.contains(conversation.id.key)

        case let .messages(upsertedIDs, removedIDs):
            !Set(
                conversation.messageIDs
            ).isDisjoint(with: upsertedIDs.union(removedIDs))

        case let .users(upsertedIDs, removedIDs):
            !Set(
                conversation.participants.map(\.userID)
            ).isDisjoint(with: upsertedIDs.union(removedIDs))
        }
    }
}
