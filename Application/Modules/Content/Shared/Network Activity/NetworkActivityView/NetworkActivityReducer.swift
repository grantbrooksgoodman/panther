//
//  NetworkActivityReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/12/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import Redux

public struct NetworkActivityReducer: Reducer {
    // MARK: - Type Aliases

    private typealias Floats = AppConstants.CGFloats.NetworkActivityView

    // MARK: - Actions

    public enum Action {
        case setIsHidden(Bool)
    }

    // MARK: - Feedback

    public enum Feedback {
        case hideIndicator
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        public var isHidden = true
        public var yOffset: CGFloat = Floats.hiddenYOffset

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Init

    public init() { RuntimeStorage.store(#file, as: .presentedViewName) }

    // MARK: - Reduce

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case let .action(.setIsHidden(isHidden)):
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            guard isHidden else {
                state.isHidden = false
                state.yOffset = 0
                return .none
            }

            return .task(delay: .seconds(1)) {
                .hideIndicator
            }

        case .feedback(.hideIndicator):
            state.isHidden = true
            state.yOffset = Floats.hiddenYOffset
        }

        return .none
    }
}
