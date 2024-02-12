//
//  RecipientBarReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public struct RecipientBarReducer: Reducer {
    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case textFieldTextChanged(String)
    }

    // MARK: - Feedback

    public enum Feedback {}

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        public var textFieldText = ""

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Init

    public init() { RuntimeStorage.store(#file, as: .presentedViewName) }

    // MARK: - Reduce

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case .action(.viewAppeared):
            break

        case let .action(.textFieldTextChanged(textFieldText)):
            state.textFieldText = textFieldText
        }

        return .none
    }
}
