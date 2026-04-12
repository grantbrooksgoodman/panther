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

struct AuthCodePageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Actions

    enum Action {
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

    struct State: Equatable {
        var instructionViewStrings: InstructionViewStrings = .empty
        var isBackButtonEnabled = true
        var isContinueButtonEnabled = false
        var strings: [TranslationOutputMap] = AuthCodePageViewStrings.defaultOutputMap
        var verificationCode = ""
        var viewState: StatefulView.ViewState = .loading
    }

    // MARK: - Reduce

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading

            return .task { @MainActor in
                let result = await translator.resolve(AuthCodePageViewStrings.self)
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
            return .task { @MainActor in
                @Dependency(\.networking.auth) var auth: any AuthDelegate
                @Dependency(\.onboardingService) var onboardingService: OnboardingService
                let result = await auth.authenticateUser(
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

private extension [TranslationOutputMap] {
    func value(for key: TranslatedLabelStringCollection.AuthCodePageViewStringKey) -> String {
        (first(where: { $0.key == .authCodePageView(key) })?.value ?? key.rawValue).sanitized
    }
}
