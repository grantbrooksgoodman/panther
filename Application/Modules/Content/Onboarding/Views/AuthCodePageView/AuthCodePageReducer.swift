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

/* 3rd-party */
import CoreArchitecture

public struct AuthCodePageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    @Navigator private var navigationCoordinator: NavigationCoordinator<RootNavigationService>

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case backButtonTapped
        case continueButtonTapped

        case didSwipeDown

        case verificationCodeChanged(String)
    }

    // MARK: - Feedback

    public enum Feedback {
        case authenticateUserReturned(Callback<String, Exception>)
        case continueButtonTapped
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
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

        // Other
        public var instructionViewStrings: InstructionViewStrings = .empty
        public var strings: [TranslationOutputMap] = AuthCodePageViewStrings.defaultOutputMap
        public var verificationCode = ""
        public var viewState: ViewState = .loading

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Reduce

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case .action(.viewAppeared):
            state.viewState = .loading

            return .task {
                let result = await networking.services.translation.resolve(AuthCodePageViewStrings.self)
                return .resolveReturned(result)
            }

        case .action(.backButtonTapped):
            navigationCoordinator.navigate(to: .onboarding(.pop))

        case .action(.continueButtonTapped):
            coreUI.resignFirstResponder()
            return .task(delay: .milliseconds(100)) {
                .continueButtonTapped
            }

        case .action(.didSwipeDown):
            coreUI.resignFirstResponder()

        case let .action(.verificationCodeChanged(verificationCode)):
            state.verificationCode = verificationCode
            state.isContinueButtonEnabled = verificationCode.count == 6

        case let .feedback(.authenticateUserReturned(.success(userID))):
            uiApplication.keyWindow?.removeOverlay()

            state.isBackButtonEnabled = true
            state.isContinueButtonEnabled = true

            onboardingService.setUserID(userID)

            navigationCoordinator.navigate(to: .onboarding(.push(.permission)))

        case let .feedback(.authenticateUserReturned(.failure(exception))):
            uiApplication.keyWindow?.removeOverlay()

            state.isBackButtonEnabled = true
            state.isContinueButtonEnabled = state.verificationCode.count == 6

            Logger.log(exception, with: .toast())

        case .feedback(.continueButtonTapped):
            state.isBackButtonEnabled = false
            state.isContinueButtonEnabled = false

            uiApplication.keyWindow?.addOverlay(alpha: 0.5, activityIndicator: (.large, .white))

            let verificationCode = state.verificationCode
            return .task {
                let result = await networking.auth.authenticateUser(
                    authID: onboardingService.authID ?? .init(),
                    verificationCode: verificationCode
                )
                return .authenticateUserReturned(result)
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
        }

        return .none
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.AuthCodePageViewStringKey) -> String {
        (first(where: { $0.key == .authCodePageView(key) })?.value ?? key.rawValue).sanitized
    }
}
