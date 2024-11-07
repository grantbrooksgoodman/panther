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

    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    @Navigator private var navigationCoordinator: NavigationCoordinator<RootNavigationService>

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case backButtonTapped
        case continueButtonTapped

        case didSwipeDown

        case phoneNumberStringChanged(String)
        case selectedRegionCodeChanged(String)
    }

    // MARK: - Feedback

    public enum Feedback {
        case accountExistsAlertDismissed(cancelled: Bool)
        case accountExistsReturned(Bool)
        case continueButtonTapped
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
        case updateRegionMenuViewID
        case verifyPhoneNumberReturned(Callback<String, Exception>)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Types */

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
        public var phoneNumberString = ""
        public var selectedRegionCode = ""

        // Other
        public var instructionViewStrings: InstructionViewStrings = .empty
        public var regionMenuViewID = UUID()
        public var strings: [TranslationOutputMap] = VerifyNumberPageViewStrings.defaultOutputMap
        public var viewState: ViewState = .loading

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

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case .action(.viewAppeared):
            state.viewState = .loading
            state.selectedRegionCode = onboardingService.regionCode ?? services.regionDetail.deviceRegionCode
            state.phoneNumberString = onboardingService.phoneNumber?.partiallyFormatted(forRegion: state.selectedRegionCode) ?? ""
            state.isContinueButtonEnabled = state.numberIsValidLength

            return .task {
                let result = await networking.translationService.resolve(VerifyNumberPageViewStrings.self)
                return .resolveReturned(result)
            }

        case .action(.backButtonTapped):
            navigationCoordinator.navigate(to: .onboarding(.pop))

        case .action(.continueButtonTapped):
            uiApplication.resignFirstResponders()
            return .task(delay: .milliseconds(100)) {
                .continueButtonTapped
            }

        case .action(.didSwipeDown):
            uiApplication.resignFirstResponders()

        case let .action(.phoneNumberStringChanged(phoneNumberString)):
            state.phoneNumberString = phoneNumberString
            state.isContinueButtonEnabled = state.numberIsValidLength

        case let .action(.selectedRegionCodeChanged(selectedRegionCode)):
            state.selectedRegionCode = selectedRegionCode
            return .task(delay: .milliseconds(500)) {
                .updateRegionMenuViewID
            }

        case let .feedback(.accountExistsAlertDismissed(cancelled: cancelled)):
            state.isBackButtonEnabled = true
            state.isContinueButtonEnabled = state.numberIsValidLength

            if !cancelled {
                onboardingService.setPhoneNumber(state.phoneNumber)
                onboardingService.setRegionCode(state.selectedRegionCode)
                navigationCoordinator.navigate(to: .onboarding(.stack([.signIn])))
            }

        case let .feedback(.accountExistsReturned(accountExists)):
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

        case .feedback(.continueButtonTapped):
            state.isBackButtonEnabled = false
            state.isContinueButtonEnabled = false

            uiApplication.mainWindow?.addOverlay(alpha: 0.5, activityIndicator: (.large, .white))

            let phoneNumber = state.phoneNumber
            return .task {
                let result = await networking.userService.accountExists(for: phoneNumber)
                return .accountExistsReturned(result)
            }

        case let .feedback(.resolveReturned(.success(strings))):
            state.strings = strings
            state.instructionViewStrings = .init(
                titleLabelText: strings.value(for: .instructionViewTitleLabelText),
                subtitleLabelText: strings.value(for: .instructionViewSubtitleLabelText)
            )
            state.viewState = .loaded

        case let .feedback(.resolveReturned(.failure(exception))):
            Logger.log(exception)
            state.instructionViewStrings = .init(
                titleLabelText: state.strings.value(for: .instructionViewTitleLabelText),
                subtitleLabelText: state.strings.value(for: .instructionViewSubtitleLabelText)
            )
            state.viewState = .loaded

        case .feedback(.updateRegionMenuViewID):
            state.regionMenuViewID = UUID()

        case let .feedback(.verifyPhoneNumberReturned(.success(authID))):
            uiApplication.mainWindow?.removeOverlay()

            state.isBackButtonEnabled = true
            state.isContinueButtonEnabled = true

            onboardingService.setAuthID(authID)
            onboardingService.setPhoneNumber(state.phoneNumber)
            onboardingService.setRegionCode(state.selectedRegionCode)

            navigationCoordinator.navigate(to: .onboarding(.push(.authCode)))

        case let .feedback(.verifyPhoneNumberReturned(.failure(exception))):
            uiApplication.mainWindow?.removeOverlay()

            state.isBackButtonEnabled = true
            state.isContinueButtonEnabled = state.numberIsValidLength

            Logger.log(exception, with: .toast())
        }

        return .none
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.VerifyNumberPageViewStringKey) -> String {
        (first(where: { $0.key == .verifyNumberPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
