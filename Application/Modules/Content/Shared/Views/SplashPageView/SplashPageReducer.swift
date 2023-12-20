//
//  SplashPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/12/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import AlertKit
import Redux

public struct SplashPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.rootNavigationCoordinator) private var navigationCoordinator: RootNavigationCoordinator
    @Dependency(\.splashPageViewService) private var viewService: SplashPageViewService

    // MARK: - Actions

    public enum Action {
        case viewAppeared
    }

    // MARK: - Feedback

    public enum Feedback {
        case errorAlertDismissed(_ actionID: Int)
        case initializedBundle(Exception?)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Init */

        public init() {}
    }

    // MARK: - Init

    public init() { RuntimeStorage.store(#file, as: .presentedViewName) }

    // MARK: - Reduce

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case .action(.viewAppeared):
            return .task {
                let result = await viewService.initializeBundle()
                return .initializedBundle(result)
            }

        case let .feedback(.errorAlertDismissed(actionID)):
            guard actionID == -1 else { return .none }
            return .task {
                let result = await viewService.initializeBundle()
                return .initializedBundle(result)
            }

        case let .feedback(.initializedBundle(exception)):
            if let exception {
                Logger.log(exception)
                return .task {
                    let result = await viewService.presentErrorAlert(exception)
                    return .errorAlertDismissed(result)
                }
            } else {
                navigationCoordinator.setPage(.onboarding(.welcome))
            }
        }

        return .none
    }
}
