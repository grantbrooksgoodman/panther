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

        case createUserFailed(Exception)
        case eulaAlertDismissed(cancelled: Bool)
        case requestContactPermissionFailed(Exception)
        case requestContactPermissionReturned(PermissionService.PermissionStatus)
        case requestNotificationPermissionFailed(Exception)
        case requestNotificationPermissionReturned(PermissionService.PermissionStatus)
        case resolveFailed(Exception)
        case resolveReturned([TranslationOutputMap])
    }

    // MARK: - State

    struct State: Equatable {
        var instructionViewStrings: InstructionViewStrings = .empty
        var isBackButtonEnabled = true
        var isContactPermissionGranted: Bool?
        var isFinishButtonEnabled = false
        var isNotificationPermissionGranted: Bool?
        var strings: [TranslationOutputMap] = PermissionPageViewStrings.defaultOutputMap
        var viewState: StatefulView.ViewState = .loading
    }

    // MARK: - Reduce

    // swiftlint:disable:next function_body_length
    func reduce(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading

            return .task {
                do throws(Exception) {
                    return try await .resolveReturned(
                        translator.resolve(PermissionPageViewStrings.self)
                    )
                } catch {
                    return .resolveFailed(error)
                }
            }

        case .backButtonTapped:
            navigation.navigate(to: .onboarding(.pop))

        case .contactPermissionCapsuleButtonTapped:
            state.isFinishButtonEnabled = state.isNotificationPermissionGranted != nil
            return .task { @MainActor in
                do throws(Exception) {
                    return try await .requestContactPermissionReturned(
                        services.permission.requestPermission(for: .contacts)
                    )
                } catch {
                    return .requestContactPermissionFailed(error)
                }
            }

        case let .createUserFailed(exception):
            coreUI.removeOverlay()
            state.isBackButtonEnabled = true
            state.isFinishButtonEnabled = true

            Logger.log(
                exception,
                with: .toast
            )

        case let .eulaAlertDismissed(cancelled: cancelled):
            guard !cancelled else {
                coreUI.removeOverlay()
                state.isBackButtonEnabled = true
                state.isFinishButtonEnabled = true
                return .none
            }

            return .task {
                @Dependency(\.onboardingService) var onboardingService: OnboardingService
                do throws(Exception) {
                    try await onboardingService.createUser()
                } catch {
                    return .createUserFailed(error)
                }

                return .none
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
                @Dependency(\.onboardingService) var onboardingService: OnboardingService
                let result = await onboardingService.presentEULAAlert()
                return .eulaAlertDismissed(cancelled: result)
            }

        case .notificationPermissionCapsuleButtonTapped:
            state.isFinishButtonEnabled = state.isContactPermissionGranted != nil
            return .task { @MainActor in
                do throws(Exception) {
                    return try await .requestNotificationPermissionReturned(
                        services.permission.requestPermission(for: .contacts)
                    )
                } catch {
                    return .requestNotificationPermissionFailed(error)
                }
            }

        case let .requestContactPermissionFailed(exception):
            guard !exception.isEqual(to: .contactAccessDenied) else {
                state.isContactPermissionGranted = false
                return .task(delay: .milliseconds(500)) {
                    @Dependency(\.commonServices) var services: CommonServices
                    await services.permission.presentCTA(for: .contacts)
                    return .none
                }
            }

            state.isBackButtonEnabled = true
            state.isFinishButtonEnabled = false

            Logger.log(
                exception,
                with: .toast
            )

        case let .requestContactPermissionReturned(status):
            state.isContactPermissionGranted = status == .granted
            if status != .granted {
                return .task(delay: .milliseconds(500)) {
                    @Dependency(\.commonServices) var services: CommonServices
                    await services.permission.presentCTA(for: .contacts)
                    return .none
                }
            } else {
                return .task {
                    @Dependency(\.commonServices) var services: CommonServices
                    do throws(Exception) {
                        try await services.contact.syncContactPairArchive()
                    } catch {
                        Logger.log(error)
                    }

                    return .none
                }
            }

        case let .requestNotificationPermissionFailed(exception):
            state.isBackButtonEnabled = true
            state.isFinishButtonEnabled = false

            Logger.log(
                exception,
                with: .toast
            )

        case let .requestNotificationPermissionReturned(status):
            state.isNotificationPermissionGranted = status == .granted
            if status != .granted {
                return .task(delay: .milliseconds(500)) {
                    @Dependency(\.commonServices) var services: CommonServices
                    await services.permission.presentCTA(for: .notifications)
                    return .none
                }
            } else {
                uiApplication.registerForRemoteNotifications()
            }

        case let .resolveFailed(exception):
            Logger.log(exception)
            state.instructionViewStrings = .init(
                titleLabelText: state.strings.value(for: .instructionViewTitleLabelText),
                subtitleLabelText: state.strings.value(for: .instructionViewSubtitleLabelText)
            )
            state.viewState = .loaded

        case let .resolveReturned(strings):
            state.strings = strings
            state.instructionViewStrings = .init(
                titleLabelText: strings.value(for: .instructionViewTitleLabelText),
                subtitleLabelText: strings.value(for: .instructionViewSubtitleLabelText)
            )
            state.viewState = .loaded
        }

        return .none
    }
}

private extension [TranslationOutputMap] {
    func value(for key: TranslatedLabelStringCollection.PermissionPageViewStringKey) -> String {
        (first(where: { $0.key == .permissionPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
