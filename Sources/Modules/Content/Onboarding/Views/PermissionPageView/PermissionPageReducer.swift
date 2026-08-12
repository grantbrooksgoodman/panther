//
//  PermissionPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable function_body_length

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem
import Networking

/// The reducer that drives the permission request page of the onboarding flow.
///
/// This page is the final step of sign-up. The user requests the contact and notification
/// permissions, agrees to the app's conduct policy, and the reducer finalizes account creation
/// with ``OnboardingService/createUser()``.
///
/// The page's behavior contract:
///
/// - On appearance, the page resolves its translated display strings, remaining in the loading
///   state until resolution completes. If resolution fails, the page falls back to its default
///   strings and loads anyway.
/// - Each permission button begins a system permission request and records the result as a
///   tri-state value: `nil` until the request resolves, then `true` or `false`. When a permission
///   is not granted, the reducer presents a call to action for it after a brief delay.
/// - When the contact permission is granted, the reducer synchronizes the contact pair archive.
///   When the notification permission is granted, the reducer registers the app for remote
///   notifications.
/// - The finish button is enabled once the status of both permissions has been determined.
///   Tapping it disables the page's buttons, presents a dimmed activity overlay, and presents the
///   conduct policy sheet.
/// - If the user agrees to the conduct policy, the reducer creates the account. If creation
///   succeeds, the reducer presents the splash page; otherwise, it removes the overlay,
///   re-enables the buttons, and surfaces the error as a toast. Declining the policy restores the
///   page without creating an account.
struct PermissionPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Actions

    /// The actions the permission page can process.
    enum Action {
        /// An action that indicates the view appeared. Begins display string resolution.
        case viewAppeared

        /// An action that indicates the user tapped the back button. Pops the current page.
        case backButtonTapped

        /// An action that indicates the user tapped the contact permission button. Begins a
        /// contact permission request.
        case contactPermissionCapsuleButtonTapped

        /// An action that indicates the user tapped the finish button. Presents the conduct
        /// policy sheet.
        case finishButtonTapped

        // swiftlint:disable identifier_name
        /// An action that indicates the user tapped the notification permission button. Begins a
        /// notification permission request.
        case notificationPermissionCapsuleButtonTapped
        // swiftlint:enable identifier_name

        /// An action that indicates account creation finished, carrying `nil` if the operation
        /// succeeded; otherwise, the resulting `Exception`.
        case createUserReturned(Exception?)

        /// An action that indicates the conduct policy sheet was dismissed, carrying a Boolean
        /// value that indicates whether the user declined the agreement.
        case eulaAlertDismissed(cancelled: Bool)

        /// An action that indicates the contact permission request failed, carrying the resulting
        /// `Exception`.
        case requestContactPermissionFailed(Exception)

        /// An action that indicates the contact permission request resolved, carrying the
        /// resulting status.
        case requestContactPermissionReturned(PermissionService.PermissionStatus)

        /// An action that indicates the notification permission request failed, carrying the
        /// resulting `Exception`.
        case requestNotificationPermissionFailed(Exception)

        /// An action that indicates the notification permission request resolved, carrying the
        /// resulting status.
        case requestNotificationPermissionReturned(PermissionService.PermissionStatus)

        /// An action that indicates display string resolution failed, carrying the resulting
        /// `Exception`.
        case resolveFailed(Exception)

        /// An action that indicates display string resolution succeeded, carrying the resolved
        /// strings.
        case resolveReturned([TranslationOutputMap])
    }

    // MARK: - State

    /// The state of the permission page.
    struct State: Equatable {
        /// The strings the page's instruction header displays. Populated once display string
        /// resolution completes.
        var instructionViewStrings: InstructionViewStrings = .empty

        /// A Boolean value that indicates whether the back button is enabled. Disabled while
        /// account creation is in progress.
        var isBackButtonEnabled = true

        /// A Boolean value that indicates whether the contact permission was granted, or `nil` if
        /// its permission request has not yet resolved.
        var isContactPermissionGranted: Bool?

        /// A Boolean value that indicates whether the finish button is enabled. Enabled once the
        /// status of both permissions has been determined; disabled while account creation is in
        /// progress.
        var isFinishButtonEnabled = false

        /// A Boolean value that indicates whether the notification permission was granted, or
        /// `nil` if its permission request has not yet resolved.
        var isNotificationPermissionGranted: Bool?

        /// The page's translated display strings. Contains the default, untranslated strings
        /// until resolution completes.
        var strings: [TranslationOutputMap] = PermissionPageViewStrings.defaultOutputMap

        /// The page's loading state. Remains `loading` until display string resolution completes.
        var viewState: StatefulView.ViewState = .loading
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
            state.viewState = .loading

            return .task {
                do throws(Exception) {
                    return try await .resolveReturned(
                        translator.resolve(PermissionPageViewStrings.self)
                    )
                } catch {
                    return .resolveFailed(error)
                }
            }

        case .backButtonTapped:
            navigation.navigate(to: .onboarding(.pop))

        case .contactPermissionCapsuleButtonTapped:
            state.isFinishButtonEnabled = state.isNotificationPermissionGranted != nil
            return .task { @MainActor in
                do throws(Exception) {
                    return try await .requestContactPermissionReturned(
                        services.permission.requestPermission(for: .contacts)
                    )
                } catch {
                    return .requestContactPermissionFailed(error)
                }
            }

        case let .createUserReturned(exception):
            coreUI.removeOverlay()

            if let exception {
                state.isBackButtonEnabled = true
                state.isFinishButtonEnabled = true

                Logger.log(
                    exception,
                    with: .toast
                )
            } else {
                navigation.navigate(to: .root(.modal(.splash)))
            }

        case let .eulaAlertDismissed(cancelled: cancelled):
            guard !cancelled else {
                coreUI.removeOverlay()
                state.isBackButtonEnabled = true
                state.isFinishButtonEnabled = true
                return .none
            }

            return .task {
                @Dependency(\.onboardingService) var onboardingService: OnboardingService
                do throws(Exception) {
                    try await onboardingService.createUser()
                    return .createUserReturned(nil)
                } catch {
                    return .createUserReturned(error)
                }
            }

        case .finishButtonTapped:
            state.isBackButtonEnabled = false
            state.isFinishButtonEnabled = false

            coreUI.addOverlay(
                alpha: 0.5,
                activityIndicator: .largeWhite,
                isModal: false
            )

            return .task {
                @Dependency(\.onboardingService) var onboardingService: OnboardingService
                let result = await onboardingService.presentEULAAlert()
                return .eulaAlertDismissed(cancelled: result)
            }

        case .notificationPermissionCapsuleButtonTapped:
            state.isFinishButtonEnabled = state.isContactPermissionGranted != nil
            return .task { @MainActor in
                do throws(Exception) {
                    return try await .requestNotificationPermissionReturned(
                        services.permission.requestPermission(for: .notifications)
                    )
                } catch {
                    return .requestNotificationPermissionFailed(error)
                }
            }

        case let .requestContactPermissionFailed(exception):
            guard !exception.isEqual(to: .contactAccessDenied) else {
                state.isContactPermissionGranted = false
                return .task(delay: .milliseconds(500)) {
                    @Dependency(\.commonServices) var services: CommonServices
                    await services.permission.presentCTA(for: .contacts)
                    return .none
                }
            }

            state.isBackButtonEnabled = true
            state.isFinishButtonEnabled = false

            Logger.log(
                exception,
                with: .toast
            )

        case let .requestContactPermissionReturned(status):
            state.isContactPermissionGranted = status == .granted
            if status != .granted {
                return .task(delay: .milliseconds(500)) {
                    @Dependency(\.commonServices) var services: CommonServices
                    await services.permission.presentCTA(for: .contacts)
                    return .none
                }
            } else {
                return .task {
                    @Dependency(\.commonServices) var services: CommonServices
                    do throws(Exception) {
                        try await services.contact.syncContactPairArchive()
                    } catch {
                        Logger.log(error)
                    }

                    return .none
                }
            }

        case let .requestNotificationPermissionFailed(exception):
            state.isBackButtonEnabled = true
            state.isFinishButtonEnabled = false

            Logger.log(
                exception,
                with: .toast
            )

        case let .requestNotificationPermissionReturned(status):
            state.isNotificationPermissionGranted = status == .granted
            if status != .granted {
                return .task(delay: .milliseconds(500)) {
                    @Dependency(\.commonServices) var services: CommonServices
                    await services.permission.presentCTA(for: .notifications)
                    return .none
                }
            } else {
                uiApplication.registerForRemoteNotifications()
            }

        case let .resolveFailed(exception):
            Logger.log(exception)
            state.instructionViewStrings = .init(
                titleLabelText: state.strings.value(for: .instructionViewTitleLabelText),
                subtitleLabelText: state.strings.value(for: .instructionViewSubtitleLabelText)
            )
            state.viewState = .loaded

        case let .resolveReturned(strings):
            state.strings = strings
            state.instructionViewStrings = .init(
                titleLabelText: strings.value(for: .instructionViewTitleLabelText),
                subtitleLabelText: strings.value(for: .instructionViewSubtitleLabelText)
            )
            state.viewState = .loaded
        }

        return .none
    }
}

private extension [TranslationOutputMap] {
    func value(for key: TranslatedLabelStringCollection.PermissionPageViewStringKey) -> String {
        (first(where: { $0.key == .permissionPageView(key) })?.value ?? key.rawValue).sanitized
    }
}

// swiftlint:enable function_body_length
