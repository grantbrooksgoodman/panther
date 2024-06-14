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
import CoreArchitecture

public struct SplashPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.clientSession.user) private var userSession: UserSessionService
    @Dependency(\.splashPageViewService) private var viewService: SplashPageViewService

    // MARK: - Properties

    @Navigator private var navigationCoordinator: NavigationCoordinator<RootNavigationService>

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
        /* MARK: Properties */

        public var isRebuildingIndices: Bool {
            @Persistent(.didClearCaches) var didClearCaches: Bool?
            return didClearCaches ?? false
        }

        public var rebuildingIndicesLabelText: String {
            Localized(.rebuildingIndices).wrappedValue.uppercased()
        }

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
            viewService.performRetryHandler()
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
            } else if userSession.currentUser != nil {
                navigationCoordinator.navigate(to: .root(.modal(.conversations)))
            } else {
                navigationCoordinator.navigate(to: .root(.modal(.onboarding)))
            }
        }

        return .none
    }
}
