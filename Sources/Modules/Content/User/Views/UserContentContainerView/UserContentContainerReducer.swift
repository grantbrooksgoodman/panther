//
//  UserContentContainerReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/10/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

struct UserContentContainerReducer: Reducer {
    // MARK: - Actions

    enum Action {
        case chatInfoToolbarButtonTapped
        case conversationMetadataChanged
    }

    // MARK: - State

    struct State: Equatable {
        var objectID = UUID()
    }

    // MARK: - Reduce

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .chatInfoToolbarButtonTapped:
            return .fireAndForget {
                Task { @MainActor in
                    RootSheets.present(.chatInfoPageView)
                }
            }

        case .conversationMetadataChanged:
            state.objectID = UUID()
        }

        return .none
    }
}
