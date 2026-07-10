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
    // MARK: - Dependencies

    @Dependency(\.navigation) private var navigation: Navigation

    // MARK: - Actions

    enum Action {
        case backButtonTapped
        case chatInfoButtonTapped
        case updateAppearance
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
            Dependency(\.clientSession.conversation.currentConversation).wrappedValue ?? .empty
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

        case .updateAppearance:
            state.viewID = UUID()
        }

        return .none
    }
}
