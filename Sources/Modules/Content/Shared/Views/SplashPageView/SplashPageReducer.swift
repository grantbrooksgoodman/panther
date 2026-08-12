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

/// The reducer that drives the splash page.
///
/// The splash page is presented at launch and after a completed sign-in or sign-up. It initializes
/// the app's data bundle through ``SplashPageViewService`` and routes the user to the appropriate
/// destination when initialization settles.
///
/// The page's behavior contract:
///
/// - On appearance, the page begins bundle initialization, racing
///   ``SplashPageViewService/initializeBundle(fromRetry:)`` against
///   ``SplashPageViewService/resolveCachedUserIfPoorNetwork()``; whichever settles first
///   determines how the app loads, and the other is cancelled.
/// - Each network activity event nudges the initialization progress forward until it approaches
///   completion, and the progress bar is shown only while a user is signed in.
/// - If initialization succeeds, the page presents the user content when a signed-in user
///   resolved; otherwise, it presents onboarding with an empty navigation stack.
/// - If initialization fails, the first failure attempts recovery automatically; subsequent
///   failures present an error alert, and dismissing it retries. In both cases, failures a
///   database repair cannot address – a timeout or a media file generation failure – retry
///   initialization directly, while all other failures run
///   ``SplashPageViewService/performRetryHandler()`` before retrying.
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

    /// The actions the splash page can process.
    enum Action {
        /// An action that indicates the view appeared. Begins bundle initialization.
        case viewAppeared

        /// An action that indicates network activity occurred. Nudges the initialization
        /// progress forward until it approaches completion.
        case bundleInitializationProgressOccurred

        /// An action that indicates the error alert was dismissed. Retries initialization,
        /// running the recovery handler first when the failure warrants it.
        case errorAlertDismissed

        /// An action that indicates bundle initialization finished, carrying `nil` if the
        /// operation succeeded; otherwise, the resulting `Exception`.
        case initializedBundle(Exception?)

        /// An action that indicates the recovery attempt finished, carrying `nil` if the
        /// operation succeeded; otherwise, the resulting `Exception`. Retries initialization.
        case performRetryHandlerReturned(Exception?)
    }

    // MARK: - State

    /// The state of the splash page.
    struct State: Equatable {
        /* MARK: Properties */

        fileprivate var didAttemptAutomaticErrorRecovery = false
        fileprivate var exception: Exception?

        /* MARK: Computed Properties */

        /// A Boolean value that indicates whether the progress bar is shown. Shown only while a
        /// user is signed in.
        var shouldShowProgressBar: Bool {
            User.currentUserID != nil
        }
    }

    // MARK: - Reduce

    /// Updates the page's state in response to the given action, returning any effect to run.
    ///
    /// - Parameters:
    ///   - state: The page's current state, mutated in place.
    ///   - action: The action to process.
    ///
    /// - Returns: An effect for the system to run, or `.none`.
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

    private static func initializeBundleTask(
        fromRetry: Bool = false
    ) -> Effect<Action> {
        .run { send in
            let viewService = Dependency(\.splashPageViewService).wrappedValue
            return await withTaskGroup(
                of: Action?.self
            ) { taskGroup in
                taskGroup.addTask {
                    do throws(Exception) {
                        try await viewService.initializeBundle(fromRetry: fromRetry)
                        return .initializedBundle(nil)
                    } catch {
                        return .initializedBundle(error)
                    }
                }

                taskGroup.addTask {
                    // Yields to initializeBundle when it settles first.
                    guard await viewService.resolveCachedUserIfPoorNetwork() else { return nil }

                    Logger.log(
                        "Loading from cached user; network is poor or initialization stalled.",
                        sender: self
                    )

                    return .initializedBundle(nil)
                }

                // First task to produce an action wins.
                for await action in taskGroup {
                    guard let action else { continue }
                    taskGroup.cancelAll()
                    await send(action)
                    break
                }
            }
        }
    }
}
