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

public struct AuthCodePageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case backButtonTapped
        case continueButtonTapped
        case didSwipeDown
        case runContinueButtonEffect

        case authenticateUserReturned(Callback<String, Exception>)
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
        case verificationCodeChanged(String)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        // Bool
        public var isBackButtonEnabled = true
        public var isContinueButtonEnabled = false

        // Other
        public var instructionViewStrings: InstructionViewStrings = .empty
        public var strings: [TranslationOutputMap] = AuthCodePageViewStrings.defaultOutputMap
        public var verificationCode = ""
        public var viewState: StatefulView.ViewState = .loading

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Reduce

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading

            return .task {
                let result = await networking.hostedTranslation.resolve(AuthCodePageViewStrings.self)
                return .resolveReturned(result)
            }

        case let .authenticateUserReturned(.success(userID)):
            coreUI.removeOverlay()

            state.isBackButtonEnabled = true
            state.isContinueButtonEnabled = true

            onboardingService.setUserID(userID)
            navigation.navigate(to: .onboarding(.push(.permission)))

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
            navigation.navigate(to: .onboarding(.pop))

        case .continueButtonTapped:
            uiApplication.resignFirstResponders()
            return .task(delay: .milliseconds(100)) {
                .runContinueButtonEffect
            }

        case .didSwipeDown:
            uiApplication.resignFirstResponders()

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

            coreUI.addOverlay(alpha: 0.5, activityIndicator: .largeWhite)

            let verificationCode = state.verificationCode
            return .task {
                let result = await networking.auth.authenticateUser(
                    authID: onboardingService.authID ?? .init(),
                    verificationCode: verificationCode
                )
                return .authenticateUserReturned(result)
            }

        case let .verificationCodeChanged(verificationCode):
            state.verificationCode = verificationCode
            state.isContinueButtonEnabled = verificationCode.count == 6
        }

        return .none
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.AuthCodePageViewStringKey) -> String {
        (first(where: { $0.key == .authCodePageView(key) })?.value ?? key.rawValue).sanitized
    }
}
