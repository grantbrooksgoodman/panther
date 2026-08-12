//
//  SignInPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/04/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length function_body_length type_body_length

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem
import Networking

/// The reducer that drives the sign-in page of the onboarding flow.
///
/// This page performs both steps of phone number verification for returning users. It begins in
/// the phone number configuration, where the user enters their phone number; once a verification
/// code has been sent, it switches to the verification code configuration, where the user enters
/// the six-digit code sent to their phone number. Authenticating successfully signs the user in.
///
/// The page's behavior contract:
///
/// - On appearance, the page resolves its translated display strings, remaining in the loading
///   state until resolution completes. If resolution fails, the page falls back to its default
///   strings and loads anyway. The page restores any phone number and region previously recorded
///   by ``OnboardingService``, defaulting to the device's region. When Developer Mode is enabled,
///   the page instead prefills a test phone number and verification code.
/// - In the phone number configuration, the continue button is enabled only while the entered
///   phone number is a valid length for the selected region's calling code. In the verification
///   code configuration, it is enabled only while the entered code is exactly six characters
///   long.
/// - Changing the selected region refreshes the region menu after a brief delay.
/// - Tapping continue dismisses the keyboard, then – after a brief delay – disables the page's
///   buttons, presents a dimmed activity overlay, and begins the current configuration's
///   operation: the account existence check in the phone number configuration, or authentication
///   in the verification code configuration. Beginning either operation cancels the other if it
///   is still in flight.
/// - If no account is registered with the phone number, the reducer offers to sign the user up
///   instead. If the user accepts, the reducer records the phone number and region with
///   ``OnboardingService`` and replaces the navigation stack with the language selection page.
/// - Otherwise, the reducer sends a verification code to the phone number and switches to the
///   verification code configuration. Tapping back in that configuration returns to the phone
///   number configuration rather than popping the page.
/// - If authentication succeeds, the reducer persists the authenticated user's identifier as the
///   signed-in user's ID, logs a sign-in analytics event, and presents the splash page. If
///   verification or authentication fails, the reducer removes the overlay, re-enables the
///   buttons, and surfaces the error as a toast. Failures caused by the user – an invalid phone
///   number, an incorrect code, an expired session, or a cancelled web context – are marked
///   non-reportable before logging.
struct SignInPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Actions

    /// The actions the sign-in page can process.
    enum Action {
        /// An action that indicates the view appeared. Restores any previously recorded phone
        /// number and region, then begins display string resolution.
        case viewAppeared

        /// An action that indicates the view disappeared. Re-enables the interactive pop gesture.
        case viewDisappeared

        /// An action that indicates the user tapped the back button. Pops the current page, or
        /// returns to the phone number configuration when entering a verification code.
        case backButtonTapped

        /// An action that indicates the user tapped the continue button. Dismisses the keyboard,
        /// then triggers ``runContinueButtonEffect`` after a brief delay.
        case continueButtonTapped

        /// An action that indicates the user swiped down on the page. Dismisses the keyboard.
        case didSwipeDown

        /// An action that begins the current configuration's operation: the account existence
        /// check in the phone number configuration, or authentication in the verification code
        /// configuration.
        case runContinueButtonEffect

        /// An action that regenerates the region menu's identity, causing it to be recreated.
        case updateRegionMenuViewID

        /// An action that indicates the account does not exist alert was dismissed, carrying a
        /// Boolean value that indicates whether the user selected the cancel option.
        case accountDoesNotExistAlertDismissed(cancelled: Bool)

        /// An action that indicates the account existence check resolved, carrying a Boolean
        /// value that indicates whether an account is registered with the entered phone number.
        case accountExistsReturned(Bool)

        /// An action that indicates authentication failed, carrying the resulting `Exception`.
        case authenticateUserFailed(Exception)

        /// An action that indicates authentication succeeded, carrying the authenticated user's
        /// identifier.
        case authenticateUserReturned(String)

        /// An action that indicates the entered phone number changed, carrying the new value.
        case phoneNumberStringChanged(String)

        /// An action that indicates display string resolution failed, carrying the resulting
        /// `Exception`.
        case resolveFailed(Exception)

        /// An action that indicates display string resolution succeeded, carrying the resolved
        /// strings.
        case resolveReturned([TranslationOutputMap])

        /// An action that indicates the selected region changed, carrying the new region code.
        /// Refreshes the region menu after a brief delay.
        case selectedRegionCodeChanged(String)

        /// An action that indicates the entered verification code changed, carrying the new
        /// value.
        case verificationCodeChanged(String)

        /// An action that indicates phone number verification failed, carrying the resulting
        /// `Exception`.
        case verifyPhoneNumberFailed(Exception)

        /// An action that indicates a verification code was sent to the entered phone number,
        /// carrying the identifier issued for the authentication attempt.
        case verifyPhoneNumberReturned(String)
    }

    // MARK: - State

    /// The state of the sign-in page.
    struct State: Equatable {
        /* MARK: Types */

        /// The input configurations the sign-in page can display.
        enum Configuration {
            /// The configuration in which the user enters their phone number.
            case phoneNumber

            /// The configuration in which the user enters the verification code sent to their
            /// phone number.
            case verificationCode
        }

        fileprivate enum TaskID {
            case authenticateUser
            case verifyPhoneNumber
        }

        /* MARK: Properties */

        /// The page's current input configuration.
        var configuration: Configuration = .phoneNumber

        /// A Boolean value that indicates whether the back button is enabled. Disabled while
        /// phone number verification or authentication is in progress.
        var isBackButtonEnabled = true

        /// A Boolean value that indicates whether the continue button is enabled. Enabled only
        /// while the current configuration's input is valid and no operation is in progress.
        var isContinueButtonEnabled = false

        /// The phone number the user has entered.
        var phoneNumberString = ""

        /// The identity of the region selection menu. Regenerated shortly after the selected
        /// region changes, causing the menu to be recreated.
        var regionMenuViewID = UUID()

        /// The code of the region the entered phone number belongs to.
        var selectedRegionCode = ""

        /// The page's translated display strings. Contains the default, untranslated strings
        /// until resolution completes.
        var strings: [TranslationOutputMap] = SignInPageViewStrings.defaultOutputMap

        /// The verification code the user has entered.
        var verificationCode = ""

        /// The page's loading state. Remains `loading` until display string resolution completes.
        var viewState: StatefulView.ViewState = .loading

        fileprivate var authID = ""

        /* MARK: Computed Properties */

        /// The continue button's title for the current configuration.
        var continueButtonText: String {
            strings.value(for: configuration == .phoneNumber ? .phoneNumberContinueButtonText : .verificationCodeContinueButtonText)
        }

        /// The instruction label's text for the current configuration.
        var instructionLabelText: String {
            strings.value(for: configuration == .phoneNumber ? .phoneNumberInstructionLabelText : .verificationCodeInstructionLabelText)
        }

        fileprivate var isDeveloperModeEnabled: Bool {
            Dependency(\.build.isDeveloperModeEnabled).wrappedValue
        }

        fileprivate var numberIsValidLength: Bool {
            @Dependency(\.commonServices.phoneNumber) var phoneNumberService: PhoneNumberService
            return phoneNumberService.numberIsValidLength(phoneNumberString.digits.count, for: phoneNumber.callingCode)
        }

        fileprivate var phoneNumber: PhoneNumber {
            @Dependency(\.commonServices) var services: CommonServices
            return .init(
                callingCode: services.regionDetail.callingCode(regionCode: selectedRegionCode) ?? services.phoneNumber.deviceCallingCode,
                nationalNumberString: phoneNumberString.digits,
                regionCode: selectedRegionCode,
                label: nil,
                internalFormattedString: nil
            )
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
            state.viewState = .loading
            state.selectedRegionCode = onboardingService.regionCode ?? services.regionDetail.deviceRegionCode

            if state.isDeveloperModeEnabled {
                state.isContinueButtonEnabled = true
                state.phoneNumberString = PhoneNumber("15558885555").partiallyFormatted(
                    forRegion: state.selectedRegionCode
                )
                state.verificationCode = "000000"
            } else {
                state.isContinueButtonEnabled = false
                state.phoneNumberString = onboardingService.phoneNumber?.partiallyFormatted(
                    forRegion: state.selectedRegionCode
                ) ?? ""
            }

            return .task {
                do throws(Exception) {
                    return try await .resolveReturned(
                        translator.resolve(SignInPageViewStrings.self)
                    )
                } catch {
                    return .resolveFailed(error)
                }
            }

        case let .accountExistsReturned(accountExists):
            if accountExists {
                let phoneNumber = state.phoneNumber
                let verifyPhoneNumberTask: Effect<Action> = .task { @MainActor in
                    @Dependency(\.networking.auth) var auth: any AuthDelegate
                    do throws(Exception) {
                        return try await .verifyPhoneNumberReturned(
                            auth.verifyPhoneNumber(
                                internationalNumber: phoneNumber.compiledNumberString
                            )
                        )
                    } catch {
                        return .verifyPhoneNumberFailed(error)
                    }
                }.cancellable(id: State.TaskID.verifyPhoneNumber)

                return .cancel(id: State.TaskID.authenticateUser)
                    .merge(with: verifyPhoneNumberTask)
            } else {
                coreUI.removeOverlay()
                return .task {
                    @Dependency(\.onboardingService) var onboardingService: OnboardingService
                    let result = await onboardingService.presentAccountDoesNotExistAlert()
                    return .accountDoesNotExistAlertDismissed(cancelled: result)
                }
            }

        case let .accountDoesNotExistAlertDismissed(cancelled: cancelled):
            coreUI.removeOverlay()

            guard !cancelled else {
                state.isBackButtonEnabled = true
                state.isContinueButtonEnabled = state.numberIsValidLength
                return .none
            }

            onboardingService.setPhoneNumber(state.phoneNumber)
            onboardingService.setRegionCode(state.selectedRegionCode)
            navigation.navigate(to: .onboarding(.stack([.selectLanguage])))

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

            @Persistent(.currentUserID) var currentUserID: String?
            currentUserID = userID
            services.analytics.logEvent(.logIn)
            navigation.navigate(to: .root(.modal(.splash)))

        case .backButtonTapped:
            switch state.configuration {
            case .phoneNumber:
                navigation.navigate(to: .onboarding(.pop))

            case .verificationCode:
                state.configuration = .phoneNumber
                state.isContinueButtonEnabled = state.numberIsValidLength
            }

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

        case let .phoneNumberStringChanged(phoneNumberString):
            state.phoneNumberString = phoneNumberString
            state.isContinueButtonEnabled = state.numberIsValidLength

        case let .resolveFailed(exception):
            Logger.log(exception)
            state.viewState = .loaded

        case let .resolveReturned(strings):
            state.strings = strings
            state.viewState = .loaded

        case .runContinueButtonEffect:
            state.isBackButtonEnabled = false
            state.isContinueButtonEnabled = false

            coreUI.addOverlay(alpha: 0.5, activityIndicator: .largeWhite)

            switch state.configuration {
            case .phoneNumber:
                let phoneNumber = state.phoneNumber
                return .task { @MainActor in
                    let result = await networking.userService.accountExists(for: phoneNumber)
                    return .accountExistsReturned(result)
                }

            case .verificationCode:
                let authID = state.authID
                let verificationCode = state.verificationCode
                let authenticateUserTask: Effect<Action> = .task { @MainActor in
                    @Dependency(\.networking.auth) var auth: any AuthDelegate
                    do throws(Exception) {
                        return try await .authenticateUserReturned(
                            auth.authenticateUser(
                                authID: authID,
                                verificationCode: verificationCode
                            )
                        )
                    } catch {
                        return .authenticateUserFailed(error)
                    }
                }.cancellable(id: State.TaskID.authenticateUser)

                return .cancel(id: State.TaskID.verifyPhoneNumber)
                    .merge(with: authenticateUserTask)
            }

        case let .selectedRegionCodeChanged(selectedRegionCode):
            state.selectedRegionCode = selectedRegionCode
            return .task(delay: .milliseconds(500)) {
                .updateRegionMenuViewID
            }

        case .updateRegionMenuViewID:
            state.regionMenuViewID = UUID()

        case let .verificationCodeChanged(verificationCode):
            state.verificationCode = verificationCode
            state.isContinueButtonEnabled = verificationCode.count == 6

        case let .verifyPhoneNumberFailed(exception):
            coreUI.removeOverlay()

            state.isBackButtonEnabled = true
            state.isContinueButtonEnabled = state.numberIsValidLength

            var exception = exception
            if let networkErrorDescriptor = exception.userInfo?["FIRAuthErrorUserInfoNameKey"] as? String,
               [
                   "ERROR_INVALID_PHONE_NUMBER",
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

        case let .verifyPhoneNumberReturned(authID):
            coreUI.removeOverlay()

            state.isBackButtonEnabled = true
            state.isContinueButtonEnabled = state.isDeveloperModeEnabled

            state.authID = authID
            state.configuration = .verificationCode

        case .viewDisappeared:
            InteractivePopGestureRecognizer.setIsEnabled(true)
        }

        return .none
    }
}

private extension [TranslationOutputMap] {
    func value(for key: TranslatedLabelStringCollection.SignInPageViewStringKey) -> String {
        (first(where: { $0.key == .signInPageView(key) })?.value ?? key.rawValue).sanitized
    }
}

// swiftlint:enable file_length function_body_length type_body_length
