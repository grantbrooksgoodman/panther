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

/// The reducer that drives the user content container.
///
/// This container hosts the signed-in user's content. It presents the chat info page and rebuilds
/// its content when the current conversation's metadata changes.
struct UserContentContainerReducer: Reducer {
    // MARK: - Actions

    /// The actions the user content container can process.
    enum Action {
        /// An action that indicates the user tapped the chat info button. Presents the chat info
        /// page.
        case chatInfoToolbarButtonTapped

        /// An action that indicates the current conversation's metadata changed. Rebuilds the
        /// container from the latest values.
        case conversationMetadataChanged
    }

    // MARK: - State

    /// The state of the user content container.
    struct State: Equatable {
        /// The identity of the container's content. Regenerated to rebuild it from the latest
        /// values.
        var objectID = UUID()
    }

    // MARK: - Reduce

    /// Updates the container's state in response to the given action, returning any effect to
    /// run.
    ///
    /// - Parameters:
    ///   - state: The container's current state, mutated in place.
    ///   - action: The action to process.
    ///
    /// - Returns: An effect for the system to run, or `.none`.
    func reduce(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
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
