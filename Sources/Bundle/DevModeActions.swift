//
//  DevModeActions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

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
                DevModeAction.AppActions.switchEnvironmentAction,
                DevModeAction.AppActions.validateDatabaseIntegrityAction,
                DevModeAction.AppActions.dangerZoneAction,
            ]

            guard Networking.config.environment != .production else { return actions }
            actions.insert(DevModeAction.AppActions.createNewMessagesAction, at: 1)
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
                        Logger.log(exception, with: .toast())
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
                        DevModeAction.AppActions.eraseDocumentsDirectoryAction,
                        DevModeAction.AppActions.eraseTemporaryDirectoryAction,
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
                    @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities
                    @Dependency(\.userDefaults) var defaults: UserDefaults
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
                        coreUtilities.clearCaches()
                        coreUtilities.eraseDocumentsDirectory()
                        coreUtilities.eraseTemporaryDirectory()

                        defaults.reset()
                    }

                    currentUserID = input
                    navigation.navigate(to: .root(.modal(.splash)))
                }
            }

            return .init(title: "Set Current User ID", perform: setCurrentUserID)
        }

        private static var switchEnvironmentAction: DevModeAction {
            func switchEnvironment() {
                Task {
                    @Sendable
                    func switchTo(_ environment: NetworkEnvironment) async {
                        @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities
                        @Dependency(\.userDefaults) var defaults: UserDefaults

                        Networking.config.setEnvironment(environment)

                        coreUtilities.clearCaches()
                        coreUtilities.eraseDocumentsDirectory()
                        coreUtilities.eraseTemporaryDirectory()

                        defaults.reset()

                        await AKAlert(
                            message: "Switched to \(environment.description) environment. You must now restart the app.",
                            actions: [.init("Exit", style: .destructivePreferred, effect: { exit(0) })]
                        ).present(translating: [])
                    }

                    let switchToDevelopmentAction: AKAction = .init("Switch to Development") {
                        Task { await switchTo(.development) }
                    }

                    let switchToProductionAction: AKAction = .init("Switch to Production", style: .destructive) {
                        Task { await switchTo(.production) }
                    }

                    let switchToStagingAction: AKAction = .init("Switch to Staging") {
                        Task { await switchTo(.staging) }
                    }

                    var actions = [AKAction]()
                    switch Networking.config.environment {
                    case .development:
                        actions = [
                            switchToProductionAction,
                            switchToStagingAction,
                        ]

                    case .production:
                        actions = [
                            switchToDevelopmentAction,
                            switchToStagingAction,
                        ]

                    case .staging:
                        actions = [
                            switchToDevelopmentAction,
                            switchToProductionAction,
                        ]
                    }

                    await AKActionSheet(
                        title: "Switch from \(Networking.config.environment.description) Environment",
                        actions: actions
                    ).present(translating: [])
                }
            }

            return .init(title: "Switch Environment", perform: switchEnvironment)
        }

        private static var validateDatabaseIntegrityAction: DevModeAction {
            func validateDatabaseIntegrity() {
                Task {
                    @Dependency(\.coreKit.hud) var coreHUD: CoreKit.HUD
                    @Dependency(\.networking.integrityService) var integrityService: IntegrityService

                    coreHUD.showProgress(isModal: true)
                    defer { coreHUD.hide() }
                    guard let exception = await integrityService.repairDatabase() else { return }
                    Logger.log(exception, with: .toast())
                }
            }

            return .init(title: "Validate Database Integrity", perform: validateDatabaseIntegrity)
        }

        // MARK: - Danger Zone Actions

        private static var deleteCurrentUserConversationsAction: DevModeAction {
            func deleteCurrentUserConversations() {
                Task {
                    @Dependency(\.coreKit) var core: CoreKit
                    @Dependency(\.userDefaults) var defaults: UserDefaults
                    @Dependency(\.navigation) var navigation: Navigation
                    @Dependency(\.clientSession.user) var userSession: UserSessionService

                    guard await AKConfirmationAlert(
                        title: "Delete Current User Conversations",
                        message: "This will delete all conversations for the current user.\n\nThis operation cannot be undone.",
                        confirmButtonStyle: .destructivePreferred
                    ).present(translating: []) else { return }

                    userSession.stopObservingCurrentUserChanges()

                    if let exception = await core.utils.deleteCurrentUserConversations() {
                        Logger.log(exception, with: .toast())
                    } else {
                        core.hud.flash(image: .success)
                        core.gcd.after(.seconds(1)) {
                            core.utils.clearCaches()
                            core.utils.eraseDocumentsDirectory()
                            core.utils.eraseTemporaryDirectory()

                            defaults.reset(preserving: .permanentAndSubsystemKeys(plus: [.userSessionService(.currentUserID)]))
                            navigation.navigate(to: .root(.modal(.splash)))
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
                    @Dependency(\.userDefaults) var defaults: UserDefaults
                    @Dependency(\.navigation) var navigation: Navigation
                    @Dependency(\.clientSession.user) var userSession: UserSessionService

                    guard await AKConfirmationAlert(
                        title: "Delete MRC Conversations",
                        message: "This will delete all Message Recipient Consent conversations for the current user.\n\nThis operation cannot be undone.",
                        confirmButtonStyle: .destructivePreferred
                    ).present(translating: []) else { return }

                    userSession.stopObservingCurrentUserChanges()

                    if let exception = await core.utils.deleteMRCConversations() {
                        Logger.log(exception, with: .toast())
                    } else {
                        core.hud.flash(image: .success)
                        core.gcd.after(.seconds(1)) {
                            core.utils.clearCaches()
                            core.utils.eraseDocumentsDirectory()
                            core.utils.eraseTemporaryDirectory()

                            defaults.reset(preserving: .permanentAndSubsystemKeys(plus: [.userSessionService(.currentUserID)]))
                            navigation.navigate(to: .root(.modal(.splash)))
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

                    let confirmed = await AKConfirmationAlert(
                        title: "Destroy Database", // swiftlint:disable:next line_length
                        message: "This will delete all conversations for all users in the \(Networking.config.environment.description.uppercased()) environment.\n\nThis operation cannot be undone.",
                        confirmButtonStyle: .destructivePreferred
                    ).present(translating: [])

                    guard confirmed else { return }
                    let doubleConfirmed = await AKConfirmationAlert(
                        title: "Are you sure?",
                        message: "ALL CONVERSATIONS FOR ALL USERS WILL BE DELETED!",
                        confirmButtonStyle: .destructivePreferred
                    ).present(translating: [])

                    guard doubleConfirmed else { return }
                    if let exception = await core.utils.destroyConversationDatabase() {
                        Logger.log(exception, with: .toast())
                    } else {
                        core.hud.flash(image: .success)
                    }
                }
            }

            return .init(title: "Destroy Conversation Database", isDestructive: true, perform: destroyConversationDatabase)
        }

        private static var eraseDocumentsDirectoryAction: DevModeAction {
            func eraseDocumentsDirectory() {
                Task {
                    @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities

                    let confirmed = await AKConfirmationAlert(
                        title: "Erase Documents Directory",
                        message: "This will remove all files in the userland Documents directory. An app restart is required.",
                        confirmButtonStyle: .destructivePreferred
                    ).present(translating: [])

                    guard confirmed else { return }
                    guard let exception = coreUtilities.eraseDocumentsDirectory() else {
                        await AKAlert(
                            message: "The Documents directory has been erased. You must now restart the app.",
                            actions: [.init("Exit", style: .destructivePreferred, effect: { exit(0) })]
                        ).present(translating: [])
                        return
                    }

                    Logger.log(exception, with: .errorAlert)
                }
            }

            return .init(title: "Erase Documents Directory", perform: eraseDocumentsDirectory)
        }

        private static var eraseTemporaryDirectoryAction: DevModeAction {
            func eraseTemporaryDirectory() {
                @Dependency(\.coreKit) var core: CoreKit
                if let exception = core.utils.eraseTemporaryDirectory() {
                    Logger.log(exception, with: .toast())
                } else {
                    core.hud.flash(image: .success)
                }
            }

            return .init(title: "Erase Temporary Directory", perform: eraseTemporaryDirectory)
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
                        Logger.log(exception, with: .toast())
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

// swiftlint:enable file_length type_body_length
