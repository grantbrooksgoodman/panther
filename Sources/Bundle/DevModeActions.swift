//
//  DevModeActions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable type_body_length

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
                DevModeAction.AppActions.setCurrentUserIDAction,
                DevModeAction.AppActions.triggerForcedUpdateModalAction,
                DevModeAction.AppActions.validateDatabaseIntegrityAction,
                DevModeAction.AppActions.dangerZoneAction,
            ]

            if Networking.config.environment != .production {
                actions.insert(DevModeAction.AppActions.createNewMessagesAction, at: 1)
            }

            if UIApplication.isFullyV26Compatible {
                actions.insert(DevModeAction.AppActions.toggleV26FeaturesAction, at: 1)
            }

            if UIApplication.v26FeaturesEnabled {
                actions.insert(DevModeAction.AppActions.toggleGlassTintingAction, at: 1)
            }

            return actions
        }

        // MARK: - Top-level Actions

        private static var createNewMessagesAction: DevModeAction {
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
                        Logger.log(exception, with: .toast)
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
                        DevModeAction.AppActions.destroyConversationDatabaseAction,
                        DevModeAction.AppActions.resetPushTokensAction,
                    ]

                    if currentUser?.conversations != nil {
                        actions.insert(
                            DevModeAction.AppActions.deleteCurrentUserConversationsAction,
                            at: 2
                        )

                        actions.insert(
                            DevModeAction.AppActions.deleteMRCConversationsAction,
                            at: 3
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

                @Persistent(.isGlassTintingEnabled) var persistedValue: Bool?
                let isGlassTintingEnabled = persistedValue == true

                persistedValue = !isGlassTintingEnabled
                UserDefaults.standard.synchronize() // NIT: Trying to force sync.

                NavigationBar.removeAllItemGlassTint()
                RootWindowScene.traitCollectionChanged()

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

                persistedValue = !v26FeaturesEnabled
                UserDefaults.standard.synchronize() // NIT: Trying to force sync.
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

        // MARK: - Danger Zone Actions

        private static var deleteCurrentUserConversationsAction: DevModeAction {
            func deleteCurrentUserConversations() {
                Task {
                    @Dependency(\.coreKit) var core: CoreKit
                    @Dependency(\.clientSession.user) var userSession: UserSessionService

                    guard await AKConfirmationAlert(
                        title: "Delete Current User Conversations",
                        message: "This will delete all conversations for the current user.\n\nThis operation cannot be undone.",
                        confirmButtonStyle: .destructivePreferred
                    ).present(translating: []) else { return }

                    userSession.stopObservingCurrentUserChanges()

                    if let exception = await core.utils.deleteCurrentUserConversations() {
                        Logger.log(exception, with: .toast)
                    } else {
                        core.hud.flash(image: .success)
                        core.gcd.after(.seconds(1)) {
                            Application.reset(
                                preserveCurrentUserID: true,
                                onCompletion: .navigateToSplash
                            )
                        }
                    }
                }
            }

            return .init(
                title: "Delete Current User Conversations",
                isDestructive: true,
                perform: deleteCurrentUserConversations
            )
        }

        private static var deleteMRCConversationsAction: DevModeAction {
            func deleteMRCConversations() {
                Task {
                    @Dependency(\.coreKit) var core: CoreKit
                    @Dependency(\.clientSession.user) var userSession: UserSessionService

                    guard await AKConfirmationAlert(
                        title: "Delete MRC Conversations",
                        message: "This will delete all Message Recipient Consent conversations for the current user.\n\nThis operation cannot be undone.",
                        confirmButtonStyle: .destructivePreferred
                    ).present(translating: []) else { return }

                    userSession.stopObservingCurrentUserChanges()

                    if let exception = await core.utils.deleteMRCConversations() {
                        Logger.log(exception, with: .toast)
                    } else {
                        core.hud.flash(image: .success)
                        core.gcd.after(.seconds(1)) {
                            Application.reset(
                                preserveCurrentUserID: true,
                                onCompletion: .navigateToSplash
                            )
                        }
                    }
                }
            }

            return .init(
                title: "Delete MRC Conversations",
                isDestructive: true,
                perform: deleteMRCConversations
            )
        }

        private static var destroyConversationDatabaseAction: DevModeAction {
            func destroyConversationDatabase() {
                Task {
                    @Dependency(\.coreKit) var core: CoreKit
                    @Dependency(\.clientSession.user) var userSession: UserSessionService

                    guard await AKConfirmationAlert(
                        title: "Destroy Database", // swiftlint:disable:next line_length
                        message: "This will delete all conversations for all users in the \(Networking.config.environment.description.uppercased()) environment.\n\nThis operation cannot be undone.",
                        confirmButtonStyle: .destructivePreferred
                    ).present(translating: []) else { return }

                    guard await AKConfirmationAlert(
                        title: "Are you sure?",
                        message: "ALL CONVERSATIONS FOR ALL USERS WILL BE DELETED!",
                        confirmButtonStyle: .destructivePreferred
                    ).present(translating: []) else { return }

                    userSession.stopObservingCurrentUserChanges()

                    if let exception = await core.utils.destroyConversationDatabase() {
                        Logger.log(exception, with: .toast)
                    } else {
                        core.hud.flash(image: .success)
                        core.gcd.after(.seconds(1)) {
                            Application.reset(
                                preserveCurrentUserID: true,
                                onCompletion: .navigateToSplash
                            )
                        }
                    }
                }
            }

            return .init(title: "Destroy Conversation Database", isDestructive: true, perform: destroyConversationDatabase)
        }

        private static var resetPushTokensAction: DevModeAction {
            func resetPushTokens() {
                Task {
                    @Dependency(\.coreKit) var core: CoreKit

                    let confirmed = await AKConfirmationAlert(
                        title: "Reset Push Tokens", // swiftlint:disable:next line_length
                        message: "This will remove all push tokens for all users in the \(Networking.config.environment.description.uppercased()) environment.\n\nThis operation cannot be undone.",
                        confirmButtonStyle: .destructivePreferred
                    ).present(translating: [])

                    guard confirmed else { return }

                    if let exception = await core.utils.resetPushTokens() {
                        Logger.log(exception, with: .toast)
                    } else {
                        core.hud.flash("Reset Push Tokens", image: .success)
                    }
                }
            }

            return .init(
                title: "Reset Push Tokens",
                isDestructive: true,
                perform: resetPushTokens
            )
        }
    }
}

// swiftlint:enable type_body_length
