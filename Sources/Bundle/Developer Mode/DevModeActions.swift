//
//  DevModeActions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

/// Use this extension to add new actions to the Developer Mode menu.
///
/// Define ``DevModeAction`` instances and include them in
/// ``AppActions/appActions`` to make them available in the Developer
/// Mode action sheet:
///
/// ```swift
/// let appActions: [DevModeAction] = [
///     .init(title: "Reset Onboarding") {
///         @Persistent(.hasSeenOnboarding) var hasSeenOnboarding: Bool?
///         hasSeenOnboarding = nil
///     },
/// ]
/// ```
///
/// - Note: Developer Mode actions are available only in pre-release builds. The subsystem
/// hides them entirely in general-release builds.
extension DevModeAction {
    /// The delegate that supplies app-specific actions to the
    /// Developer Mode menu.
    struct AppActions: AppSubsystem.Delegates.DevModeAppActionDelegate {
        // MARK: - Properties

        /// The actions to display in the Developer Mode action sheet.
        var appActions: [DevModeAction] {
            var actions = [
                Breadcrumbs.manageBreadcrumbsCaptureAction,
                AppActions.setCurrentUserIDAction,
                AppActions.triggerForcedUpdateModalAction,
                AppActions.validateDatabaseIntegrityAction,
                AppActions.dangerZoneAction,
            ]

            if Networking.config.environment != .production {
                actions.insert(AppActions.createNewMessagesAction, at: 1)
            }

            return actions
        }

        // MARK: - Top-level Actions

        static var createNewMessagesAction: DevModeAction {
            @Sendable
            func createNewMessages() {
                Task { @MainActor in
                    @Dependency(\.networking.userService.testing) var userTestingService: UserTestingService

                    let messageCount = await AKTextInputAlert(
                        title: "Create Random Messages",
                        message: "Enter the amount of messages to be created.",
                        attributes: .init(keyboardType: .numberPad)
                    ).present(translating: [])

                    guard let messageCount,
                          let integer = Int(messageCount) else { return }

                    if let exception = await userTestingService.createRandomMessages(count: integer) {
                        Logger.log(
                            exception,
                            with: .errorAlert
                        )

                        Application.reset(onCompletion: .navigateToSplash)
                    }
                }
            }

            return .init(title: "Create New Random Messages", perform: createNewMessages)
        }

        private static var dangerZoneAction: DevModeAction {
            @Sendable
            func dangerZone() {
                Task {
                    @Dependency(\.clientSession.user.currentUser) var currentUser: User?

                    var actions: [DevModeAction] = [
                        DevModeAction.AppActions.DangerZone.destroyConversationDatabaseAction,
                        DevModeAction.AppActions.DangerZone.resetPushTokensAction,
                    ]

                    if currentUser?.previousLanguageCodes?.isEmpty == false {
                        actions.insert(
                            DevModeAction.AppActions.DangerZone.clearPreviousLanguageCodesAction,
                            at: 0
                        )
                    }

                    if currentUser?.conversations != nil {
                        actions.insert(
                            DevModeAction.AppActions.DangerZone.deleteConversationsAction,
                            at: 1
                        )
                    }

                    await AKActionSheet(
                        title: "Danger Zone",
                        message: "Exercise caution when using these options.",
                        actions: actions.map {
                            AKAction(
                                $0.title,
                                style: $0.isDestructive ? .destructive : .default,
                                effect: $0.perform
                            )
                        }
                    ).present(translating: [])
                }
            }

            return .init(title: "Danger Zone", isDestructive: true, perform: dangerZone)
        }

        private static var setCurrentUserIDAction: DevModeAction {
            @Sendable
            func setCurrentUserID() {
                Task { @MainActor in
                    @Dependency(\.navigation) var navigation: Navigation
                    @Persistent(.currentUserID) var currentUserID: String?

                    let input = await AKTextInputAlert(
                        message: "Set Current User ID",
                        attributes: .init(
                            capitalizationType: .none,
                            correctionType: .no
                        ),
                        confirmButtonTitle: "Done"
                    ).present(translating: [])

                    guard let input else { return }
                    if input != currentUserID {
                        Application.reset()
                    }

                    currentUserID = input
                    navigation.navigate(to: .root(.modal(.splash)))
                }
            }

            return .init(title: "Set Current User ID", perform: setCurrentUserID)
        }

        private static var triggerForcedUpdateModalAction: DevModeAction {
            @Sendable
            func triggerForcedUpdateModal() {
                @Dependency(\.commonServices.update) var updateService: UpdateService
                updateService.isForcedUpdateRequiredSubject.send(true)
            }

            return .init(title: "Trigger Forced Update Modal", perform: triggerForcedUpdateModal)
        }

        private static var validateDatabaseIntegrityAction: DevModeAction {
            @Sendable
            func validateDatabaseIntegrity() {
                Task {
                    @Dependency(\.coreKit.hud) var coreHUD: CoreKit.HUD
                    @Dependency(\.networking.integrityService) var integrityService: IntegrityService

                    coreHUD.showProgress(isModal: true)
                    defer { coreHUD.hide() }
                    guard let exception = await integrityService.repairDatabase() else { return }
                    Logger.log(exception, with: .toast)
                }
            }

            return .init(title: "Validate Database Integrity", perform: validateDatabaseIntegrity)
        }
    }
}
