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

/* 3rd-party */
import Redux

public struct VerifyNumberPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.rootNavigationCoordinator) private var navigationCoordinator: RootNavigationCoordinator
    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.uiApplication) private var uiApplication: UIApplication
    @Dependency(\.verifyNumberPageViewService) private var viewService: VerifyNumberPageViewService

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
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
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
        public var strings: [TranslationOutputMap] = VerifyNumberPageViewStrings.defaultOutputMap
        public var viewState: ViewState = .loading

        /* MARK: Computed Properties */

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
        case .action(.viewAppeared):
            state.viewState = .loading
            state.selectedRegionCode = services.regionDetail.deviceRegionCode

            return .task {
                let result = await networking.services.translation.resolve(VerifyNumberPageViewStrings.self)
                return .resolveReturned(result)
            }

        case .action(.backButtonTapped):
            navigationCoordinator.setPage(.onboarding(.selectLanguage))

        case .action(.continueButtonTapped):
            state.isBackButtonEnabled = false
            state.isContinueButtonEnabled = false

            coreUI.resignFirstResponder()
            uiApplication.keyWindow?.addOverlay(alpha: 0.5, activityIndicator: (.large, .white))

            let phoneNumber: PhoneNumber = .init(state.phoneNumberString)
            return .task {
                let result = await viewService.accountExists(for: phoneNumber)
                return .accountExistsReturned(result)
            }

        case .action(.didSwipeDown):
            coreUI.resignFirstResponder()

        case let .action(.phoneNumberStringChanged(phoneNumberString)):
            state.phoneNumberString = phoneNumberString
            state.isContinueButtonEnabled = services.phoneNumber.numberIsValidLength(
                phoneNumberString.digits.count,
                for: state.phoneNumber.callingCode
            )

        case let .action(.selectedRegionCodeChanged(selectedRegionCode)):
            state.selectedRegionCode = selectedRegionCode

        case let .feedback(.accountExistsAlertDismissed(cancelled: cancelled)):
            state.isBackButtonEnabled = true
            state.isContinueButtonEnabled = services.phoneNumber.numberIsValidLength(
                state.phoneNumberString.digits.count,
                for: state.phoneNumber.callingCode
            )

            if !cancelled {
                // TODO: Navigate to sign in page with same number.
                onboardingService.setPhoneNumber(state.phoneNumber)
                navigationCoordinator.setPage(.sample)
            }

        case let .feedback(.accountExistsReturned(accountExists)):
            if accountExists {
                uiApplication.keyWindow?.removeOverlay()
                return .task {
                    let result = await viewService.presentAccountExistsAlert()
                    return .accountExistsAlertDismissed(cancelled: result)
                }
            } else {
                let phoneNumber = state.phoneNumber
                return .task {
                    let result = await networking.auth.verifyPhoneNumber(internationalNumber: phoneNumber.compiledNumberString)
                    return .verifyPhoneNumberReturned(result)
                }
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
            state.viewState = .loaded

        case let .feedback(.verifyPhoneNumberReturned(.success(authID))):
            uiApplication.keyWindow?.removeOverlay()

            state.isBackButtonEnabled = true
            state.isContinueButtonEnabled = true

            onboardingService.setAuthID(authID)
            onboardingService.setPhoneNumber(state.phoneNumber)
            onboardingService.setRegionCode(state.selectedRegionCode)

            navigationCoordinator.setPage(.onboarding(.authCode))

        case let .feedback(.verifyPhoneNumberReturned(.failure(exception))):
            uiApplication.keyWindow?.removeOverlay()

            state.isBackButtonEnabled = true
            state.isContinueButtonEnabled = services.phoneNumber.numberIsValidLength(
                state.phoneNumberString.digits.count,
                for: state.phoneNumber.callingCode
            )

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
