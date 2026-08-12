//
//  AuthCodePageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem
import Networking

/// The reducer that drives the verification code entry page of the onboarding flow.
///
/// This page is the second step of phone number verification. The user enters the six-digit code
/// sent to their phone number, and the reducer authenticates them using that code together with
/// the authentication identifier recorded by ``OnboardingService`` when the code was sent.
///
/// The page's behavior contract:
///
/// - On appearance, the page resolves its translated display strings, remaining in the loading
///   state until resolution completes. If resolution fails, the page falls back to its default
///   strings and loads anyway.
/// - The continue button is enabled only while the entered code is exactly six characters long.
/// - Tapping continue dismisses the keyboard, then – after a brief delay – disables the page's
///   buttons, presents a dimmed activity overlay, and begins authentication.
/// - If authentication succeeds, the reducer records the authenticated user's identifier with
///   ``OnboardingService/setUserID(_:)`` and pushes the permission page.
/// - If authentication fails, the reducer removes the overlay, re-enables the buttons, and
///   surfaces the error as a toast. Failures caused by the user – an incorrect code, an expired
///   session, or a cancelled web context – are marked non-reportable before logging.
struct AuthCodePageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Actions

    /// The actions the verification code entry page can process.
    enum Action {
        /// An action that indicates the view appeared. Begins display string resolution.
        case viewAppeared

        /// An action that indicates the user tapped the back button. Pops the current page.
        case backButtonTapped

        /// An action that indicates the user tapped the continue button. Dismisses the keyboard,
        /// then triggers ``runContinueButtonEffect`` after a brief delay.
        case continueButtonTapped

        /// An action that indicates the user swiped down on the page. Dismisses the keyboard.
        case didSwipeDown

        /// An action that begins authenticating the user with the entered verification code.
        case runContinueButtonEffect

        /// An action that indicates authentication failed, carrying the resulting `Exception`.
        case authenticateUserFailed(Exception)

        /// An action that indicates authentication succeeded, carrying the authenticated user's
        /// identifier.
        case authenticateUserReturned(String)

        /// An action that indicates display string resolution failed, carrying the resulting
        /// `Exception`.
        case resolveFailed(Exception)

        /// An action that indicates display string resolution succeeded, carrying the resolved
        /// strings.
        case resolveReturned([TranslationOutputMap])

        /// An action that indicates the entered verification code changed, carrying the new
        /// value.
        case verificationCodeChanged(String)
    }

    // MARK: - State

    /// The state of the verification code entry page.
    struct State: Equatable {
        /// The strings the page's instruction header displays. Populated once display string
        /// resolution completes.
        var instructionViewStrings: InstructionViewStrings = .empty

        /// A Boolean value that indicates whether the back button is enabled. Disabled while
        /// authentication is in progress.
        var isBackButtonEnabled = true

        /// A Boolean value that indicates whether the continue button is enabled. Enabled only
        /// while the entered code is exactly six characters long and authentication is not in
        /// progress.
        var isContinueButtonEnabled = false

        /// The page's translated display strings. Contains the default, untranslated strings
        /// until resolution completes.
        var strings: [TranslationOutputMap] = AuthCodePageViewStrings.defaultOutputMap

        /// The verification code the user has entered.
        var verificationCode = ""

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

            return .task { @MainActor in
                do throws(Exception) {
                    return try await .resolveReturned(
                        translator.resolve(AuthCodePageViewStrings.self)
                    )
                } catch {
                    return .resolveFailed(error)
                }
            }

        case let .authenticateUserFailed(exception):
            coreUI.removeOverlay()

            state.isBackButtonEnabled = true
            state.isContinueButtonEnabled = state.verificationCode.count == 6

            var exception = exception
            if let networkErrorDescriptor = exception.userInfo?["FIRAuthErrorUserInfoNameKey"] as? String,
               [
                   "ERROR_INVALID_VERIFICATION_CODE",
                   "ERROR_SESSION_EXPIRED",
                   "ERROR_WEB_CONTEXT_CANCELLED",
               ].contains(networkErrorDescriptor) {
                exception = .init(
                    exception.descriptor,
                    isReportable: false,
                    userInfo: exception.userInfo,
                    underlyingExceptions: exception.underlyingExceptions,
                    metadata: exception.metadata
                )
            }

            Logger.log(
                exception,
                with: .toast
            )

        case let .authenticateUserReturned(userID):
            coreUI.removeOverlay()

            state.isBackButtonEnabled = true
            state.isContinueButtonEnabled = true

            onboardingService.setUserID(userID)
            navigation.navigate(to: .onboarding(.push(.permission)))

        case .backButtonTapped:
            navigation.navigate(to: .onboarding(.pop))

        case .continueButtonTapped:
            let continueButtonEffect: Effect<Action> = .task(delay: .milliseconds(100)) {
                .runContinueButtonEffect
            }

            return .fireAndForget { @MainActor in
                uiApplication.resignFirstResponders()
            }.merge(with: continueButtonEffect)

        case .didSwipeDown:
            return .fireAndForget { @MainActor in
                uiApplication.resignFirstResponders()
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

        case .runContinueButtonEffect:
            state.isBackButtonEnabled = false
            state.isContinueButtonEnabled = false

            coreUI.addOverlay(alpha: 0.5, activityIndicator: .largeWhite)

            let verificationCode = state.verificationCode
            return .task { @MainActor in
                @Dependency(\.networking.auth) var auth: any AuthDelegate
                @Dependency(\.onboardingService) var onboardingService: OnboardingService
                do throws(Exception) {
                    return try await .authenticateUserReturned(
                        auth.authenticateUser(
                            authID: onboardingService.authID ?? .init(),
                            verificationCode: verificationCode
                        )
                    )
                } catch {
                    return .authenticateUserFailed(error)
                }
            }

        case let .verificationCodeChanged(verificationCode):
            state.verificationCode = verificationCode
            state.isContinueButtonEnabled = verificationCode.count == 6
        }

        return .none
    }
}

private extension [TranslationOutputMap] {
    func value(for key: TranslatedLabelStringCollection.AuthCodePageViewStringKey) -> String {
        (first(where: { $0.key == .authCodePageView(key) })?.value ?? key.rawValue).sanitized
    }
}
