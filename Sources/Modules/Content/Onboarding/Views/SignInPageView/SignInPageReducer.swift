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

    enum Action {
        case viewAppeared
        case viewDisappeared

        case backButtonTapped
        case continueButtonTapped
        case didSwipeDown
        case runContinueButtonEffect
        case updateRegionMenuViewID

        case accountDoesNotExistAlertDismissed(cancelled: Bool)
        case accountExistsReturned(Bool)
        case authenticateUserFailed(Exception)
        case authenticateUserReturned(String)
        case phoneNumberStringChanged(String)
        case resolveFailed(Exception)
        case resolveReturned([TranslationOutputMap])
        case selectedRegionCodeChanged(String)
        case verificationCodeChanged(String)
        case verifyPhoneNumberFailed(Exception)
        case verifyPhoneNumberReturned(String)
    }

    // MARK: - State

    struct State: Equatable {
        /* MARK: Types */

        enum Configuration {
            case phoneNumber
            case verificationCode
        }

        fileprivate enum TaskID {
            case authenticateUser
            case verifyPhoneNumber
        }

        /* MARK: Properties */

        var configuration: Configuration = .phoneNumber
        var isBackButtonEnabled = true
        var isContinueButtonEnabled = false
        var phoneNumberString = ""
        var regionMenuViewID = UUID()
        var selectedRegionCode = ""
        var strings: [TranslationOutputMap] = SignInPageViewStrings.defaultOutputMap
        var verificationCode = ""
        var viewState: StatefulView.ViewState = .loading

        fileprivate var authID = ""

        /* MARK: Computed Properties */

        var continueButtonText: String {
            strings.value(for: configuration == .phoneNumber ? .phoneNumberContinueButtonText : .verificationCodeContinueButtonText)
        }

        var instructionLabelText: String {
            strings.value(for: configuration == .phoneNumber ? .phoneNumberInstructionLabelText : .verificationCodeInstructionLabelText)
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

    // swiftlint:disable:next function_body_length
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading
            state.selectedRegionCode = onboardingService.regionCode ?? services.regionDetail.deviceRegionCode
            state.phoneNumberString = onboardingService.phoneNumber?.partiallyFormatted(forRegion: state.selectedRegionCode) ?? ""
            state.isContinueButtonEnabled = state.numberIsValidLength

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

            Logger.log(exception, with: .toast)

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

            Logger.log(exception, with: .toast)

        case let .verifyPhoneNumberReturned(authID):
            coreUI.removeOverlay()

            state.isBackButtonEnabled = true
            state.isContinueButtonEnabled = false

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
