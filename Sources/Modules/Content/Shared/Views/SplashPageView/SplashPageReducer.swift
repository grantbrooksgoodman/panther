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

struct SplashPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.clientSession.entity.user) private var userSession: UserSessionService
    @Dependency(\.splashPageViewService) private var viewService: SplashPageViewService

    // MARK: - Properties

    private static let performRetryHandlerTask: Effect<Action> = .task {
        @Dependency(\.splashPageViewService) var viewService: SplashPageViewService
        do throws(Exception) {
            try await viewService.performRetryHandler()
            return .performRetryHandlerReturned(nil)
        } catch {
            return .performRetryHandlerReturned(error)
        }
    }

    // MARK: - Actions

    enum Action {
        case viewAppeared
        case bundleInitializationProgressOccurred
        case errorAlertDismissed

        case initializedBundle(Exception?)
        case performRetryHandlerReturned(Exception?)
    }

    // MARK: - State

    struct State: Equatable {
        /* MARK: Properties */

        fileprivate var didAttemptAutomaticErrorRecovery = false
        fileprivate var exception: Exception?

        /* MARK: Computed Properties */

        var shouldShowProgressBar: Bool {
            User.currentUserID != nil
        }
    }

    // MARK: - Reduce

    func reduce(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.didAttemptAutomaticErrorRecovery = false
            return Self.initializeBundleTask()

        case .bundleInitializationProgressOccurred:
            guard viewService.initializationProgress < 0.8 else { return .none }
            viewService.initializationProgress += 0.0005

        case .errorAlertDismissed:
            guard let exception = state.exception,
                  !exception.isEqual(toAny: [
                      .failedToGenerateMediaFile,
                      .timedOut,
                  ]) else { return Self.initializeBundleTask(fromRetry: true) }

            return Self.performRetryHandlerTask

        case let .initializedBundle(exception):
            state.exception = exception

            if let exception {
                defer { Logger.log(exception) }

                guard state.didAttemptAutomaticErrorRecovery else {
                    Logger.log(
                        "Attempting automatic error recovery.",
                        sender: self
                    )

                    state.didAttemptAutomaticErrorRecovery = true
                    guard !exception.isEqual(
                        toAny: [
                            .failedToGenerateMediaFile,
                            .timedOut,
                        ]
                    ) else {
                        return Self.initializeBundleTask(fromRetry: true)
                    }

                    return Self.performRetryHandlerTask
                }

                return .task {
                    await viewService.presentErrorAlert(exception)
                    return .errorAlertDismissed
                }
            } else if User.currentUserID != nil,
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

            return Self.initializeBundleTask(fromRetry: true)
        }

        return .none
    }

    // MARK: - Auxiliary

    // TODO: Audit the code style here. Likely can be cleaned up.
    private static func initializeBundleTask(
        fromRetry: Bool = false
    ) -> Effect<Action> {
        .task {
            await withTaskGroup(of: Action.self) { taskGroup in
                taskGroup.addTask {
                    @Dependency(\.splashPageViewService) var viewService: SplashPageViewService

                    do throws(Exception) {
                        try await viewService.initializeBundle(fromRetry: fromRetry)
                        return .initializedBundle(nil)
                    } catch {
                        return .initializedBundle(error)
                    }
                }

                taskGroup.addTask {
                    @Dependency(\.clientSession.entity.user.currentUser) var currentUser: User?
                    @Dependency(\.splashPageViewService) var viewService: SplashPageViewService

                    guard await viewService.resolveCachedUserIfPoorNetwork() else {
                        // Network is healthy; yield to initializeBundle.
                        while !Task.isCancelled {
                            try? await Task.sleep(for: .seconds(60))
                        }

                        return .initializedBundle(nil)
                    }

                    Logger.log(
                        "Loading from cached user due to poor network health.",
                        with: .toastInPrerelease(style: .warning),
                        sender: self
                    )

                    Task.detached(priority: .background) {
                        if RuntimeStorage.lastSignInDate == nil {
                            try? await currentUser?.updateLastSignedInDate()
                        }
                    }

                    return .initializedBundle(nil)
                }

                // First task to finish wins.
                let taskGroupResult = await taskGroup.next()!
                taskGroup.cancelAll()
                return taskGroupResult
            }
        }
    }
}
