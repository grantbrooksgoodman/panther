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

/// The reducer that drives ``ChatPageHeaderView``.
///
/// The header's behavior contract:
///
/// - Tapping the back button pops the user content navigation stack.
/// - Tapping the chat info button presents the chat info page sheet.
/// - When the session store reports a change affecting the current conversation, its messages,
///   or its participants, the header reloads after a short delay; rapid successive changes
///   coalesce into a single reload.
struct ChatPageHeaderReducer: Reducer {
    // MARK: - Types

    private enum TaskID: String {
        case reloadData
    }

    // MARK: - Dependencies

    @Dependency(\.navigation) private var navigation: Navigation

    // MARK: - Actions

    /// The actions the chat page header can process.
    enum Action {
        /// An action that indicates the user tapped the back button. Pops the user content
        /// navigation stack.
        case backButtonTapped

        /// An action that indicates the user tapped the chat info button. Presents the chat
        /// info page sheet.
        case chatInfoButtonTapped

        /// An action that regenerates the view's identity, forcing it to rebuild.
        case reloadData

        /// An action that indicates the session store changed, carrying the change. Reloads
        /// the header after a short delay when the change affects the current conversation,
        /// its messages, or its participants.
        case sessionStoreDidChange(SessionStoreChange)
    }

    // MARK: - State

    /// The state of the chat page header.
    struct State: Equatable {
        /* MARK: Properties */

        /// The identity of the view; assigning a new value forces the view to rebuild.
        var viewID = UUID()

        /* MARK: Computed Properties */

        /// The conversation cell view data used to render the header's avatar and title.
        @MainActor
        var cellViewData: ConversationCellViewData {
            .init(conversation) ?? .empty
        }

        /// The conversation the header describes – the session's current conversation, or an
        /// empty placeholder if none is set.
        var conversation: Conversation {
            Dependency(
                \.clientSession.entity.conversation.currentConversation
            ).wrappedValue ?? .empty
        }
    }

    // MARK: - Reduce

    /// Updates the header's state in response to the given action, returning any effect to
    /// run.
    ///
    /// - Parameters:
    ///   - state: The header's current state, mutated in place.
    ///   - action: The action to process.
    ///
    /// - Returns: An effect for the system to run, or `.none`.
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
