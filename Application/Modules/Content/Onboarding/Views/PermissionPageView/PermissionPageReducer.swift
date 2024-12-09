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

public struct PermissionPageReducer: Reducer {
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
        case finishButtonTapped

        case contactPermissionCapsuleButtonTapped // swiftlint:disable:next identifier_name
        case notificationPermissionCapsuleButtonTapped
    }

    // MARK: - Feedback

    public enum Feedback {
        case createUserReturned(Exception?)
        case eulaAlertDismissed(cancelled: Bool)
        case requestContactPermissionReturned(Callback<PermissionService.PermissionStatus, Exception>)
        case requestNotificationPermissionReturned(Callback<PermissionService.PermissionStatus, Exception>)
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
        public var isContactPermissionGranted: Bool?
        public var isFinishButtonEnabled = false
        public var isNotificationPermissionGranted: Bool?

        // Other
        public var instructionViewStrings: InstructionViewStrings = .empty
        public var strings: [TranslationOutputMap] = PermissionPageViewStrings.defaultOutputMap
        public var viewState: ViewState = .loading

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Reduce

    // swiftlint:disable:next function_body_length
    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case .action(.viewAppeared):
            state.viewState = .loading

            return .task {
                let result = await networking.translationService.resolve(PermissionPageViewStrings.self)
                return .resolveReturned(result)
            }

        case .action(.backButtonTapped):
            navigationCoordinator.navigate(to: .onboarding(.pop))

        case .action(.finishButtonTapped):
            state.isBackButtonEnabled = false
            state.isFinishButtonEnabled = false

            uiApplication.mainWindow?.addOverlay(alpha: 0.5, activityIndicator: (.large, .white))

            return .task {
                let result = await onboardingService.presentEULAAlert()
                return .eulaAlertDismissed(cancelled: result)
            }

        case .action(.contactPermissionCapsuleButtonTapped):
            state.isFinishButtonEnabled = state.isNotificationPermissionGranted != nil
            return .task {
                let result = await services.permission.requestPermission(for: .contacts)
                return .requestContactPermissionReturned(result)
            }

        case .action(.notificationPermissionCapsuleButtonTapped):
            state.isFinishButtonEnabled = state.isContactPermissionGranted != nil
            return .task {
                let result = await services.permission.requestPermission(for: .notifications)
                return .requestNotificationPermissionReturned(result)
            }

        case let .feedback(.createUserReturned(exception)):
            uiApplication.mainWindow?.removeOverlay()

            if let exception {
                state.isBackButtonEnabled = true
                state.isFinishButtonEnabled = false

                Logger.log(exception, with: .toast())
            } else {
                navigationCoordinator.navigate(to: .root(.modal(.splash)))
            }

        case let .feedback(.eulaAlertDismissed(cancelled: cancelled)):
            guard !cancelled else {
                uiApplication.mainWindow?.removeOverlay()
                state.isBackButtonEnabled = true
                state.isFinishButtonEnabled = true
                return .none
            }

            return .task {
                let result = await onboardingService.createUser()
                return .createUserReturned(result)
            }

        case let .feedback(.requestContactPermissionReturned(.success(status))):
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

        case let .feedback(.requestContactPermissionReturned(.failure(exception))):
            guard !exception.isEqual(to: .contactAccessDenied) else {
                state.isContactPermissionGranted = false
                return .task(delay: .milliseconds(500)) {
                    await services.permission.presentCTA(for: .contacts)
                    return .none
                }
            }

            state.isBackButtonEnabled = true
            state.isFinishButtonEnabled = false

            Logger.log(exception, with: .toast())

        case let .feedback(.requestNotificationPermissionReturned(.success(status))):
            state.isNotificationPermissionGranted = status == .granted
            if status != .granted {
                return .task(delay: .milliseconds(500)) {
                    await services.permission.presentCTA(for: .notifications)
                    return .none
                }
            } else {
                uiApplication.registerForRemoteNotifications()
            }

        case let .feedback(.requestNotificationPermissionReturned(.failure(exception))):
            state.isBackButtonEnabled = true
            state.isFinishButtonEnabled = false

            Logger.log(exception, with: .toast())

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
    func value(for key: TranslatedLabelStringCollection.PermissionPageViewStringKey) -> String {
        (first(where: { $0.key == .permissionPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
