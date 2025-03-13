//
//  SplashPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/12/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AlertKit
import AppSubsystem

public struct SplashPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.navigation) private var navigation: NavigationCoordinator<RootNavigationService>
    @Dependency(\.clientSession.user) private var userSession: UserSessionService
    @Dependency(\.splashPageViewService) private var viewService: SplashPageViewService

    // MARK: - Actions

    public enum Action {
        case viewAppeared
        case bundleInitializationProgressOccurred
        case errorAlertDismissed

        case initializedBundle(Exception?)
        case performRetryHandlerReturned(Exception?)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        public var didAttemptAutomaticErrorRecovery = false
        public var exception: Exception?

        /* MARK: Computed Properties */

        public var shouldShowProgressBar: Bool {
            @Persistent(.currentUserID) var currentUserID: String?
            return currentUserID != nil
        }

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Reduce

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.didAttemptAutomaticErrorRecovery = false
            return .task {
                let result = await viewService.initializeBundle()
                return .initializedBundle(result)
            }

        case .bundleInitializationProgressOccurred:
            guard viewService.initializationProgress < 0.8 else { return .none }
            viewService.initializationProgress += 0.0005

        case .errorAlertDismissed:
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

        case let .initializedBundle(exception):
            @Persistent(.currentUserID) var currentUserID: String?
            state.exception = exception

            if let exception {
                defer { Logger.log(exception) }

                guard state.didAttemptAutomaticErrorRecovery else {
                    state.didAttemptAutomaticErrorRecovery = true
                    return .task {
                        let result = await viewService.performRetryHandler()
                        return .performRetryHandlerReturned(result)
                    }
                }

                return .task {
                    await viewService.presentErrorAlert(exception)
                    return .errorAlertDismissed
                }
            } else if currentUserID != nil,
                      userSession.currentUser != nil {
                navigation.navigate(to: .root(.modal(.userContent)))
            } else {
                navigation.navigate(to: .onboarding(.stack([])))
                navigation.navigate(to: .root(.modal(.onboarding)))
            }

        case let .performRetryHandlerReturned(exception):
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
