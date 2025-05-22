//
//  VerifyNumberPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem
import Networking

public struct VerifyNumberPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case backButtonTapped
        case continueButtonTapped
        case didSwipeDown
        case runContinueButtonEffect
        case updateRegionMenuViewID

        case accountExistsAlertDismissed(cancelled: Bool)
        case accountExistsReturned(Bool)
        case phoneNumberStringChanged(String)
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
        case selectedRegionCodeChanged(String)
        case verifyPhoneNumberReturned(Callback<String, Exception>)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        // Bool
        public var isBackButtonEnabled = true
        public var isContinueButtonEnabled = false

        // String
        public var phoneNumberString = ""
        public var selectedRegionCode = ""

        // Other
        public var instructionViewStrings: InstructionViewStrings = .empty
        public var regionMenuViewID = UUID()
        public var strings: [TranslationOutputMap] = VerifyNumberPageViewStrings.defaultOutputMap
        public var viewState: StatefulView.ViewState = .loading

        /* MARK: Computed Properties */

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
                let result = await networking.hostedTranslation.resolve(VerifyNumberPageViewStrings.self)
                return .resolveReturned(result)
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
                uiApplication.mainWindow?.removeOverlay()
                return .task {
                    let result = await onboardingService.presentAccountExistsAlert()
                    return .accountExistsAlertDismissed(cancelled: result)
                }
            } else {
                let phoneNumber = state.phoneNumber
                return .task {
                    let result = await networking.auth.verifyPhoneNumber(internationalNumber: phoneNumber.compiledNumberString)
                    return .verifyPhoneNumberReturned(result)
                }
            }

        case .backButtonTapped:
            navigation.navigate(to: .onboarding(.pop))

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
            state.instructionViewStrings = .init(
                titleLabelText: strings.value(for: .instructionViewTitleLabelText),
                subtitleLabelText: strings.value(for: .instructionViewSubtitleLabelText)
            )
            state.viewState = .loaded

        case let .resolveReturned(.failure(exception)):
            Logger.log(exception)
            state.instructionViewStrings = .init(
                titleLabelText: state.strings.value(for: .instructionViewTitleLabelText),
                subtitleLabelText: state.strings.value(for: .instructionViewSubtitleLabelText)
            )
            state.viewState = .loaded

        case .runContinueButtonEffect:
            state.isBackButtonEnabled = false
            state.isContinueButtonEnabled = false

            uiApplication.mainWindow?.addOverlay(alpha: 0.5, activityIndicator: .largeWhite)

            let phoneNumber = state.phoneNumber
            return .task {
                let result = await networking.userService.accountExists(for: phoneNumber)
                return .accountExistsReturned(result)
            }

        case let .selectedRegionCodeChanged(selectedRegionCode):
            state.selectedRegionCode = selectedRegionCode
            return .task(delay: .milliseconds(500)) {
                .updateRegionMenuViewID
            }

        case .updateRegionMenuViewID:
            state.regionMenuViewID = UUID()

        case let .verifyPhoneNumberReturned(.success(authID)):
            uiApplication.mainWindow?.removeOverlay()

            state.isBackButtonEnabled = true
            state.isContinueButtonEnabled = true

            onboardingService.setAuthID(authID)
            onboardingService.setPhoneNumber(state.phoneNumber)
            onboardingService.setRegionCode(state.selectedRegionCode)

            navigation.navigate(to: .onboarding(.push(.authCode)))

        case let .verifyPhoneNumberReturned(.failure(exception)):
            uiApplication.mainWindow?.removeOverlay()

            state.isBackButtonEnabled = true
            state.isContinueButtonEnabled = state.numberIsValidLength

            var exception = exception
            if let networkErrorDescriptor = exception.extraParams?["FIRAuthErrorUserInfoNameKey"] as? String,
               [
                   "ERROR_INVALID_PHONE_NUMBER",
                   "ERROR_SESSION_EXPIRED",
                   "ERROR_WEB_CONTEXT_CANCELLED",
               ].contains(networkErrorDescriptor) {
                exception = .init(
                    exception.descriptor,
                    isReportable: false,
                    extraParams: exception.extraParams,
                    underlyingExceptions: exception.underlyingExceptions,
                    metadata: exception.metadata
                )
            }

            Logger.log(exception, with: .toast)
        }

        return .none
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.VerifyNumberPageViewStringKey) -> String {
        (first(where: { $0.key == .verifyNumberPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
