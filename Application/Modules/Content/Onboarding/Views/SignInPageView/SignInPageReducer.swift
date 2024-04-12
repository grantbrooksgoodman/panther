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

/* 3rd-party */
import Redux

public struct SignInPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.rootNavigationCoordinator) private var navigationCoordinator: RootNavigationCoordinator
    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.networking.services.translation) private var translator: HostedTranslationService
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case backButtonTapped
        case continueButtonTapped

        case didSwipeDown

        case phoneNumberStringChanged(String)
        case selectedRegionCodeChanged(String)
        case verificationCodeChanged(String)
    }

    // MARK: - Feedback

    public enum Feedback {
        case accountDoesNotExistAlertDismissed(cancelled: Bool)
        case accountExistsReturned(Bool)
        case authenticateUserReturned(Callback<String, Exception>)
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
        case updateRegionMenuViewID
        case verifyPhoneNumberReturned(Callback<String, Exception>)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Types */

        public enum Configuration {
            case phoneNumber
            case verificationCode
        }

        public enum ViewState: Equatable {
            case loading
            case error(Exception)
            case loaded
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
        public var viewState: ViewState = .loading

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

    // MARK: - Init

    public init() { RuntimeStorage.store(#file, as: .presentedViewName) }

    // MARK: - Reduce

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case let .action(action):
            return reduce(into: &state, for: action)

        case let .feedback(feedback):
            return reduce(into: &state, for: feedback)
        }
    }

    // MARK: - Reduce Action

    private func reduce(into state: inout State, for action: Action) -> Effect<Feedback> {
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

        case .backButtonTapped:
            switch state.configuration {
            case .phoneNumber:
                navigationCoordinator.setPage(.onboarding(.welcome))

            case .verificationCode:
                state.configuration = .phoneNumber
                state.isContinueButtonEnabled = state.numberIsValidLength
            }

        case .continueButtonTapped:
            state.isBackButtonEnabled = false
            state.isContinueButtonEnabled = false

            coreUI.resignFirstResponder()
            uiApplication.keyWindow?.addOverlay(alpha: 0.5, activityIndicator: (.large, .white))

            switch state.configuration {
            case .phoneNumber:
                let phoneNumber = state.phoneNumber
                return .task {
                    let result = await networking.services.user.accountExists(for: phoneNumber)
                    return .accountExistsReturned(result)
                }

            case .verificationCode:
                let authID = state.authID
                let verificationCode = state.verificationCode
                return .task {
                    let result = await networking.auth.authenticateUser(
                        authID: authID,
                        verificationCode: verificationCode
                    )
                    return .authenticateUserReturned(result)
                }
            }

        case .didSwipeDown:
            coreUI.resignFirstResponder()

        case let .phoneNumberStringChanged(phoneNumberString):
            state.phoneNumberString = phoneNumberString
            state.isContinueButtonEnabled = state.numberIsValidLength

        case let .selectedRegionCodeChanged(selectedRegionCode):
            state.selectedRegionCode = selectedRegionCode
            return .task(delay: .milliseconds(500)) {
                .updateRegionMenuViewID
            }

        case let .verificationCodeChanged(verificationCode):
            state.verificationCode = verificationCode
            state.isContinueButtonEnabled = verificationCode.count == 6
        }

        return .none
    }

    // MARK: - Reduce Feedback

    private func reduce(into state: inout State, for feedback: Feedback) -> Effect<Feedback> {
        switch feedback {
        case let .accountExistsReturned(accountExists):
            if accountExists {
                let phoneNumber = state.phoneNumber
                return .task {
                    let result = await networking.auth.verifyPhoneNumber(internationalNumber: phoneNumber.compiledNumberString)
                    return .verifyPhoneNumberReturned(result)
                }
            } else {
                uiApplication.keyWindow?.removeOverlay()
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
            navigationCoordinator.setPage(.onboarding(.selectLanguage))

        case let .authenticateUserReturned(.success(userID)):
            uiApplication.keyWindow?.removeOverlay()

            @Persistent(.currentUserID) var currentUserID: String?
            currentUserID = userID
            navigationCoordinator.setPage(.splash)

        case let .authenticateUserReturned(.failure(exception)):
            uiApplication.keyWindow?.removeOverlay()

            state.isBackButtonEnabled = true
            state.isContinueButtonEnabled = state.verificationCode.count == 6

            Logger.log(exception, with: .toast())

        case let .resolveReturned(.success(strings)):
            state.strings = strings
            state.viewState = .loaded

        case let .resolveReturned(.failure(exception)):
            Logger.log(exception)
            state.viewState = .loaded

        case .updateRegionMenuViewID:
            state.regionMenuViewID = UUID()

        case let .verifyPhoneNumberReturned(.success(authID)):
            uiApplication.keyWindow?.removeOverlay()

            state.isBackButtonEnabled = true
            state.isContinueButtonEnabled = false

            state.authID = authID
            state.configuration = .verificationCode

        case let .verifyPhoneNumberReturned(.failure(exception)):
            uiApplication.keyWindow?.removeOverlay()

            state.isBackButtonEnabled = true
            state.isContinueButtonEnabled = state.numberIsValidLength

            Logger.log(exception, with: .toast())
        }

        return .none
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.SignInPageViewStringKey) -> String {
        (first(where: { $0.key == .signInPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
