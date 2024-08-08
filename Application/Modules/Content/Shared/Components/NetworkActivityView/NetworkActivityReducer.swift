//
//  NetworkActivityReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/12/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public struct NetworkActivityReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build

    // MARK: - Actions

    public enum Action {
        case isVisibleChanged(Bool)
    }

    // MARK: - Feedback

    public enum Feedback {
        case hideIndicator
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Constants Accessors */

        public typealias Floats = AppConstants.CGFloats.NetworkActivityView

        /* MARK: Types */

        public enum TaskID {
            case hideIndicator
        }

        /* MARK: Properties */

        public var isVisible = false
        public var yOffset: CGFloat = Floats.hiddenYOffset

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Reduce

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case let .action(.isVisibleChanged(isVisible)):
            @Persistent(.indicatesNetworkActivity) var indicatesNetworkActivity: Bool?
            var canShowIndicator: Bool {
                guard build.stage != .generalRelease,
                      build.developerModeEnabled,
                      let indicatesNetworkActivity,
                      indicatesNetworkActivity else { return false }
                return true
            }

            var hideIndicatorTask: Effect<Feedback> {
                .cancel(id: State.TaskID.hideIndicator)
                    .merge(with:
                        .task(delay: .seconds(State.Floats.hideIndicatorTaskDelaySeconds)) {
                            .hideIndicator
                        }
                        .cancellable(id: State.TaskID.hideIndicator)
                    )
            }

            guard isVisible,
                  state.isVisible != canShowIndicator else { return hideIndicatorTask }
            state.isVisible = canShowIndicator
            state.yOffset = canShowIndicator ? 0 : State.Floats.hiddenYOffset
            return hideIndicatorTask

        case .feedback(.hideIndicator):
            guard state.isVisible else { return .none }
            state.isVisible = false
            state.yOffset = State.Floats.hiddenYOffset
        }

        return .none
    }
}
