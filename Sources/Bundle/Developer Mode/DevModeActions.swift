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

/**
 Use this extension to add new actions to the Developer Mode menu.
 */
public extension DevModeAction {
    struct AppActions: AppSubsystem.Delegates.DevModeAppActionDelegate {
        // MARK: - Properties

        public var appActions: [DevModeAction] {
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

            if UIApplication.isFullyV26Compatible {
                actions.insert(AppActions.toggleV26FeaturesAction, at: 1)
            }

            if UIApplication.v26FeaturesEnabled {
                actions.insert(AppActions.toggleGlassTintingAction, at: 1)
            }

            return actions
        }

        // MARK: - Top-level Actions

        static var createNewMessagesAction: DevModeAction {
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
            func setCurrentUserID() {
                Task {
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

        private static var toggleGlassTintingAction: DevModeAction {
            func toggleGlassTintingAction() {
                @Dependency(\.coreKit) var core: CoreKit

                @Persistent(.isGlassTintingEnabled) var persistedValue: Bool? // TODO: Audit this logic.
                Application.toggleGlassTinting(on: !(persistedValue == true))

                core.hud.showSuccess(
                    text: "Glass Tinting \(persistedValue == true ? "Enabled" : "Disabled")"
                )
            }

            return .init(
                title: "Toggle Glass Tinting",
                perform: toggleGlassTintingAction
            )
        }

        private static var toggleV26FeaturesAction: DevModeAction {
            @Persistent(.v26FeaturesEnabled) var persistedValue: Bool?
            let v26FeaturesEnabled = persistedValue == true

            func toggleV26Features() {
                @Dependency(\.coreKit) var core: CoreKit
                @Dependency(\.userDefaults) var defaults: UserDefaults

                persistedValue = !v26FeaturesEnabled
                defaults.synchronize() // NIT: Trying to force sync.
                core.hud.showSuccess(
                    text: "v26 Features \(persistedValue == true ? "Enabled" : "Disabled")"
                )

                core.gcd.after(.seconds(1)) {
                    StatusBar.setIsHidden(true)
                    core.ui.addOverlay(activityIndicator: .largeWhite)
                    core.gcd.after(.seconds(1)) { core.utils.exitGracefully() }
                }
            }

            return .init(
                title: "\(v26FeaturesEnabled ? "Disable" : "Enable") v26 Features",
                perform: toggleV26Features
            )
        }

        private static var triggerForcedUpdateModalAction: DevModeAction {
            func triggerForcedUpdateModal() {
                @Dependency(\.commonServices.update) var updateService: UpdateService
                updateService.isForcedUpdateRequiredSubject.send(true)
            }

            return .init(title: "Trigger Forced Update Modal", perform: triggerForcedUpdateModal)
        }

        private static var validateDatabaseIntegrityAction: DevModeAction {
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
