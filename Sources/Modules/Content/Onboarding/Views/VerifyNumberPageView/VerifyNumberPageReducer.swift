//
//  VerifyNumberPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable function_body_length

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem
import Networking

/// The reducer that drives the phone number entry page of the onboarding flow.
///
/// This page is the first step of phone number verification. The user enters their phone number,
/// and the reducer checks whether an account is already registered with it before sending a
/// verification code.
///
/// The page's behavior contract:
///
/// - On appearance, the page resolves its translated display strings, remaining in the loading
///   state until resolution completes. If resolution fails, the page falls back to its default
///   strings and loads anyway. The page restores any phone number and region previously recorded
///   by ``OnboardingService``, defaulting to the device's region.
/// - The continue button is enabled only while the entered phone number is a valid length for the
///   selected region's calling code.
/// - Changing the selected region refreshes the region menu after a brief delay.
/// - Tapping continue dismisses the keyboard, then – after a brief delay – disables the page's
///   buttons, presents a dimmed activity overlay, and begins the account existence check.
/// - If an account is already registered with the phone number, the reducer offers to sign the
///   user in instead. If the user accepts, the reducer records the phone number and region with
///   ``OnboardingService`` and replaces the navigation stack with the sign-in page.
/// - Otherwise, the reducer sends a verification code to the phone number. When the code is sent,
///   the reducer records the issued identifier, phone number, and region with
///   ``OnboardingService`` and pushes the verification code entry page.
/// - If verification fails, the reducer removes the overlay, re-enables the buttons, and surfaces
///   the error as a toast. Failures caused by the user – an invalid phone number, an expired
///   session, or a cancelled web context – are marked non-reportable before logging.
struct VerifyNumberPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Actions

    /// The actions the phone number entry page can process.
    enum Action {
        /// An action that indicates the view appeared. Restores any previously recorded phone
        /// number and region, then begins display string resolution.
        case viewAppeared

        /// An action that indicates the user tapped the back button. Pops the current page.
        case backButtonTapped

        /// An action that indicates the user tapped the continue button. Dismisses the keyboard,
        /// then triggers ``runContinueButtonEffect`` after a brief delay.
        case continueButtonTapped

        /// An action that indicates the user swiped down on the page. Dismisses the keyboard.
        case didSwipeDown

        /// An action that begins checking whether an account exists for the entered phone number.
        case runContinueButtonEffect

        /// An action that regenerates the region menu's identity, causing it to be recreated.
        case updateRegionMenuViewID

        /// An action that indicates the account exists alert was dismissed, carrying a Boolean
        /// value that indicates whether the user selected the cancel option.
        case accountExistsAlertDismissed(cancelled: Bool)

        /// An action that indicates the account existence check resolved, carrying a Boolean
        /// value that indicates whether an account is registered with the entered phone number.
        case accountExistsReturned(Bool)

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

        /// An action that indicates phone number verification failed, carrying the resulting
        /// `Exception`.
        case verifyPhoneNumberFailed(Exception)

        /// An action that indicates a verification code was sent to the entered phone number,
        /// carrying the identifier issued for the authentication attempt.
        case verifyPhoneNumberReturned(String)
    }

    // MARK: - State

    /// The state of the phone number entry page.
    struct State: Equatable {
        /* MARK: Properties */

        /// The strings the page's instruction header displays. Populated once display string
        /// resolution completes.
        var instructionViewStrings: InstructionViewStrings = .empty

        /// A Boolean value that indicates whether the back button is enabled. Disabled while
        /// phone number verification is in progress.
        var isBackButtonEnabled = true

        /// A Boolean value that indicates whether the continue button is enabled. Enabled only
        /// while the entered phone number is a valid length for the selected region's calling
        /// code and phone number verification is not in progress.
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
        var strings: [TranslationOutputMap] = VerifyNumberPageViewStrings.defaultOutputMap

        /// The page's loading state. Remains `loading` until display string resolution completes.
        var viewState: StatefulView.ViewState = .loading

        /* MARK: Computed Properties */

        fileprivate var numberIsValidLength: Bool {
            @Dependency(\.commonServices.phoneNumber) var phoneNumberService: PhoneNumberService
            return phoneNumberService.numberIsValidLength(
                phoneNumberString.digits.count,
                for: phoneNumber.callingCode
            )
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
            state.phoneNumberString = onboardingService.phoneNumber?.partiallyFormatted(forRegion: state.selectedRegionCode) ?? ""
            state.isContinueButtonEnabled = state.numberIsValidLength

            return .task { @MainActor in
                do throws(Exception) {
                    return try await .resolveReturned(
                        translator.resolve(VerifyNumberPageViewStrings.self)
                    )
                } catch {
                    return .resolveFailed(error)
                }
            }

        case let .accountExistsAlertDismissed(cancelled: cancelled):
            state.isBackButtonEnabled = true
            state.isContinueButtonEnabled = state.numberIsValidLength

            if !cancelled {
                onboardingService.setPhoneNumber(state.phoneNumber)
                onboardingService.setRegionCode(state.selectedRegionCode)
                navigation.navigate(to: .onboarding(.stack([.signIn])))
            }

        case let .accountExistsReturned(accountExists):
            if accountExists {
                coreUI.removeOverlay()
                return .task {
                    @Dependency(\.onboardingService) var onboardingService: OnboardingService
                    let result = await onboardingService.presentAccountExistsAlert()
                    return .accountExistsAlertDismissed(cancelled: result)
                }
            } else {
                let phoneNumber = state.phoneNumber
                return .task { @MainActor in
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
                }
            }

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

        case let .phoneNumberStringChanged(phoneNumberString):
            state.phoneNumberString = phoneNumberString
            state.isContinueButtonEnabled = state.numberIsValidLength

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

            let phoneNumber = state.phoneNumber
            return .task {
                @Dependency(\.networking.userService) var userService: UserService
                let result = await userService.accountExists(for: phoneNumber)
                return .accountExistsReturned(result)
            }

        case let .selectedRegionCodeChanged(selectedRegionCode):
            state.selectedRegionCode = selectedRegionCode
            return .task(delay: .milliseconds(500)) {
                .updateRegionMenuViewID
            }

        case .updateRegionMenuViewID:
            state.regionMenuViewID = UUID()

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
            state.isContinueButtonEnabled = true

            onboardingService.setAuthID(authID)
            onboardingService.setPhoneNumber(state.phoneNumber)
            onboardingService.setRegionCode(state.selectedRegionCode)

            navigation.navigate(to: .onboarding(.push(.authCode)))
        }

        return .none
    }
}

private extension [TranslationOutputMap] {
    func value(for key: TranslatedLabelStringCollection.VerifyNumberPageViewStringKey) -> String {
        (first(where: { $0.key == .verifyNumberPageView(key) })?.value ?? key.rawValue).sanitized
    }
}

// swiftlint:enable function_body_length
