//
//  PermissionPageReducer.swift
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

struct PermissionPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Actions

    enum Action {
        case viewAppeared

        case backButtonTapped
        case contactPermissionCapsuleButtonTapped
        case finishButtonTapped // swiftlint:disable:next identifier_name
        case notificationPermissionCapsuleButtonTapped

        case createUserReturned(Exception?)
        case eulaAlertDismissed(cancelled: Bool)
        case requestContactPermissionReturned(Callback<PermissionService.PermissionStatus, Exception>)
        case requestNotificationPermissionReturned(Callback<PermissionService.PermissionStatus, Exception>)
        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
    }

    // MARK: - State

    struct State: Equatable {
        /* MARK: Properties */

        // Bool
        var isBackButtonEnabled = true
        var isContactPermissionGranted: Bool?
        var isFinishButtonEnabled = false
        var isNotificationPermissionGranted: Bool?

        // Other
        var instructionViewStrings: InstructionViewStrings = .empty
        var strings: [TranslationOutputMap] = PermissionPageViewStrings.defaultOutputMap
        var viewState: StatefulView.ViewState = .loading

        /* MARK: Init */

        init() {}
    }

    // MARK: - Reduce

    // swiftlint:disable:next function_body_length
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading

            return .task {
                let result = await translator.resolve(PermissionPageViewStrings.self)
                return .resolveReturned(result)
            }

        case .backButtonTapped:
            navigation.navigate(to: .onboarding(.pop))

        case .contactPermissionCapsuleButtonTapped:
            state.isFinishButtonEnabled = state.isNotificationPermissionGranted != nil
            return .task {
                let result = await services.permission.requestPermission(for: .contacts)
                return .requestContactPermissionReturned(result)
            }

        case let .createUserReturned(exception):
            coreUI.removeOverlay()

            if let exception {
                state.isBackButtonEnabled = true
                state.isFinishButtonEnabled = false

                Logger.log(exception, with: .toast)
            } else {
                navigation.navigate(to: .root(.modal(.splash)))
            }

        case let .eulaAlertDismissed(cancelled: cancelled):
            guard !cancelled else {
                coreUI.removeOverlay()
                state.isBackButtonEnabled = true
                state.isFinishButtonEnabled = true
                return .none
            }

            return .task {
                let result = await onboardingService.createUser()
                return .createUserReturned(result)
            }

        case .finishButtonTapped:
            state.isBackButtonEnabled = false
            state.isFinishButtonEnabled = false

            coreUI.addOverlay(
                alpha: 0.5,
                activityIndicator: .largeWhite,
                isModal: false
            )

            return .task {
                let result = await onboardingService.presentEULAAlert()
                return .eulaAlertDismissed(cancelled: result)
            }

        case .notificationPermissionCapsuleButtonTapped:
            state.isFinishButtonEnabled = state.isContactPermissionGranted != nil
            return .task {
                let result = await services.permission.requestPermission(for: .notifications)
                return .requestNotificationPermissionReturned(result)
            }

        case let .requestContactPermissionReturned(.success(status)):
            state.isContactPermissionGranted = status == .granted
            if status != .granted {
                return .task(delay: .milliseconds(500)) {
                    await services.permission.presentCTA(for: .contacts)
                    return .none
                }
            } else {
                return .task {
                    if let exception = await services.contact.syncContactPairArchive() {
                        Logger.log(exception)
                    }

                    return .none
                }
            }

        case let .requestContactPermissionReturned(.failure(exception)):
            guard !exception.isEqual(to: .contactAccessDenied) else {
                state.isContactPermissionGranted = false
                return .task(delay: .milliseconds(500)) {
                    await services.permission.presentCTA(for: .contacts)
                    return .none
                }
            }

            state.isBackButtonEnabled = true
            state.isFinishButtonEnabled = false

            Logger.log(exception, with: .toast)

        case let .requestNotificationPermissionReturned(.success(status)):
            state.isNotificationPermissionGranted = status == .granted
            if status != .granted {
                return .task(delay: .milliseconds(500)) {
                    await services.permission.presentCTA(for: .notifications)
                    return .none
                }
            } else {
                uiApplication.registerForRemoteNotifications()
            }

        case let .requestNotificationPermissionReturned(.failure(exception)):
            state.isBackButtonEnabled = true
            state.isFinishButtonEnabled = false

            Logger.log(exception, with: .toast)

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
        }

        return .none
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.PermissionPageViewStringKey) -> String {
        (first(where: { $0.key == .permissionPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
