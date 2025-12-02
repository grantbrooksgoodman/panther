//
//  EmptyReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

struct EmptyReducer: Reducer {
    // MARK: - Actions

    enum Action {
        case viewAppeared
    }

    // MARK: - State

    struct State: Equatable {}

    // MARK: - Reduce

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            break
        }

        return .none
    }
}
