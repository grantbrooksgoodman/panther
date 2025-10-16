//
//  SignInPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/04/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem
import Networking

public struct SignInPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Actions

    public enum Action {
        case viewAppeared
        case viewDisappeared

        case backButtonTapped
        case continueButtonTapped
        case didSwipeDown
        case runContinueButtonEffect
        case updateRegionMenuViewID

        case accountDoesNotExistAlertDismissed(cancelled: Bool)
        case accountExistsReturned(Bool)
        case authenticateUserReturned(Callback<String, Exception>)
        case phoneNumberStringChanged(String)
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
        case selectedRegionCodeChanged(String)
        case verificationCodeChanged(String)
        case verifyPhoneNumberReturned(Callback<String, Exception>)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Types */

        public enum Configuration {
            case phoneNumber
            case verificationCode
        }

        fileprivate enum TaskID {
            case authenticateUser
            case verifyPhoneNumber
        }

        /* MARK: Properties */

        // Bool
        public var isBackButtonEnabled = true
        public var isContinueButtonEnabled = false

        // String
        public var authID = ""
        public var phoneNumberString = ""
        public var selectedRegionCode = ""
        public var verificationCode = ""

        // Other
        public var configuration: Configuration = .phoneNumber
        public var regionMenuViewID = UUID()
        public var strings: [TranslationOutputMap] = SignInPageViewStrings.defaultOutputMap
        public var viewState: StatefulView.ViewState = .loading

        /* MARK: Computed Properties */

        public var continueButtonText: String {
            strings.value(for: configuration == .phoneNumber ? .phoneNumberContinueButtonText : .verificationCodeContinueButtonText)
        }

        public var instructionLabelText: String {
            strings.value(for: configuration == .phoneNumber ? .phoneNumberInstructionLabelText : .verificationCodeInstructionLabelText)
        }

        public var numberIsValidLength: Bool {
            @Dependency(\.commonServices.phoneNumber) var phoneNumberService: PhoneNumberService
            return phoneNumberService.numberIsValidLength(phoneNumberString.digits.count, for: phoneNumber.callingCode)
        }

        public var phoneNumber: PhoneNumber {
            @Dependency(\.commonServices) var services: CommonServices
            return .init(
                callingCode: services.regionDetail.callingCode(regionCode: selectedRegionCode) ?? services.phoneNumber.deviceCallingCode,
                nationalNumberString: phoneNumberString.digits,
                regionCode: selectedRegionCode,
                label: nil,
                internalFormattedString: nil
            )
        }

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Reduce

    // swiftlint:disable:next function_body_length
    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading
            state.selectedRegionCode = onboardingService.regionCode ?? services.regionDetail.deviceRegionCode
            state.phoneNumberString = onboardingService.phoneNumber?.partiallyFormatted(forRegion: state.selectedRegionCode) ?? ""
            state.isContinueButtonEnabled = state.numberIsValidLength

            return .task {
                let result = await translator.resolve(SignInPageViewStrings.self)
                return .resolveReturned(result)
            }

        case let .accountExistsReturned(accountExists):
            if accountExists {
                let phoneNumber = state.phoneNumber
                let verifyPhoneNumberTask: Effect<Action> = .task {
                    let result = await networking.auth.verifyPhoneNumber(internationalNumber: phoneNumber.compiledNumberString)
                    return .verifyPhoneNumberReturned(result)
                }.cancellable(id: State.TaskID.verifyPhoneNumber)
                return .cancel(id: State.TaskID.authenticateUser).merge(with: verifyPhoneNumberTask)
            } else {
                coreUI.removeOverlay()
                return .task {
                    let result = await onboardingService.presentAccountDoesNotExistAlert()
                    return .accountDoesNotExistAlertDismissed(cancelled: result)
                }
            }

        case let .accountDoesNotExistAlertDismissed(cancelled: cancelled):
            guard !cancelled else {
                state.isBackButtonEnabled = true
                state.isContinueButtonEnabled = state.numberIsValidLength
                return .none
            }

            onboardingService.setPhoneNumber(state.phoneNumber)
            onboardingService.setRegionCode(state.selectedRegionCode)
            navigation.navigate(to: .onboarding(.stack([.selectLanguage])))

        case let .authenticateUserReturned(.success(userID)):
            coreUI.removeOverlay()

            @Persistent(.currentUserID) var currentUserID: String?
            currentUserID = userID
            services.analytics.logEvent(.logIn)
            navigation.navigate(to: .root(.modal(.splash)))

        case let .authenticateUserReturned(.failure(exception)):
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

            Logger.log(exception, with: .toast)

        case .backButtonTapped:
            switch state.configuration {
            case .phoneNumber:
                navigation.navigate(to: .onboarding(.pop))

            case .verificationCode:
                state.configuration = .phoneNumber
                state.isContinueButtonEnabled = state.numberIsValidLength
            }

        case .continueButtonTapped:
            uiApplication.resignFirstResponders()
            return .task(delay: .milliseconds(100)) {
                .runContinueButtonEffect
            }

        case .didSwipeDown:
            uiApplication.resignFirstResponders()

        case let .phoneNumberStringChanged(phoneNumberString):
            state.phoneNumberString = phoneNumberString
            state.isContinueButtonEnabled = state.numberIsValidLength

        case let .resolveReturned(.success(strings)):
            state.strings = strings
            state.viewState = .loaded

        case let .resolveReturned(.failure(exception)):
            Logger.log(exception)
            state.viewState = .loaded

        case .runContinueButtonEffect:
            state.isBackButtonEnabled = false
            state.isContinueButtonEnabled = false

            coreUI.addOverlay(alpha: 0.5, activityIndicator: .largeWhite)

            switch state.configuration {
            case .phoneNumber:
                let phoneNumber = state.phoneNumber
                return .task {
                    let result = await networking.userService.accountExists(for: phoneNumber)
                    return .accountExistsReturned(result)
                }

            case .verificationCode:
                let authID = state.authID
                let verificationCode = state.verificationCode
                let authenticateUserTask: Effect<Action> = .task {
                    let result = await networking.auth.authenticateUser(
                        authID: authID,
                        verificationCode: verificationCode
                    )
                    return .authenticateUserReturned(result)
                }.cancellable(id: State.TaskID.authenticateUser)
                return .cancel(id: State.TaskID.verifyPhoneNumber).merge(with: authenticateUserTask)
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

        case let .verifyPhoneNumberReturned(.success(authID)):
            coreUI.removeOverlay()

            state.isBackButtonEnabled = true
            state.isContinueButtonEnabled = false

            state.authID = authID
            state.configuration = .verificationCode

        case let .verifyPhoneNumberReturned(.failure(exception)):
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

        case .viewDisappeared:
            InteractivePopGestureRecognizer.setIsEnabled(true)
        }

        return .none
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.SignInPageViewStringKey) -> String {
        (first(where: { $0.key == .signInPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
