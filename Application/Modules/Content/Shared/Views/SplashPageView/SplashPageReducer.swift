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
        case errorAlertDismissed
        case initializedBundle(Exception?)
        case performRetryHandlerReturned(Exception?)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        public var exception: Exception?

        /* MARK: Computed Properties */

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

        case .feedback(.errorAlertDismissed):
            guard let exception = state.exception,
                  !exception.isEqual(to: .timedOut) else {
                return .task {
                    let result = await viewService.initializeBundle()
                    return .initializedBundle(result)
                }
            }

            return .task {
                let result = await viewService.performRetryHandler()
                return .performRetryHandlerReturned(result)
            }

        case let .feedback(.initializedBundle(exception)):
            @Persistent(.currentUserID) var currentUserID: String?
            state.exception = exception

            if let exception {
                Logger.log(exception)
                return .task {
                    await viewService.presentErrorAlert(exception)
                    return .errorAlertDismissed
                }
            } else if currentUserID != nil,
                      userSession.currentUser != nil {
                navigationCoordinator.navigate(to: .root(.modal(.conversations)))
            } else {
                navigationCoordinator.navigate(to: .onboarding(.stack([])))
                navigationCoordinator.navigate(to: .root(.modal(.onboarding)))
            }

        case let .feedback(.performRetryHandlerReturned(exception)):
            if let exception {
                Logger.log(exception)
            }

            return .task {
                let result = await viewService.initializeBundle()
                return .initializedBundle(result)
            }
        }

        return .none
    }
}
