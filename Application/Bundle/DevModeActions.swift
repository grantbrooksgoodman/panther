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
                DevModeAction.AppActions.clearCachesAction,
                DevModeAction.AppActions.resetUserDefaultsAction,
                DevModeAction.AppActions.setCurrentUserIDAction,
                DevModeAction.AppActions.switchEnvironmentAction,
                DevModeAction.AppActions.dangerZoneAction,
            ]

            guard Networking.config.environment != .production else { return actions }
            actions.insert(DevModeAction.AppActions.createNewMessagesAction, at: 1)
            return actions
        }

        // MARK: - Top-level Actions

        private static var clearCachesAction: DevModeAction {
            func clearCaches() {
                @Dependency(\.coreKit) var core: CoreKit
                core.utils.clearCaches()
                core.hud.flash(image: .success)
            }

            return .init(title: "Clear Caches", perform: clearCaches)
        }

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
                    let actions: [AKAction] = [
                        DevModeAction.AppActions.eraseDocumentsDirectoryAction,
                        DevModeAction.AppActions.eraseTemporaryDirectoryAction,
                        DevModeAction.AppActions.destroyConversationDatabaseAction,
                        DevModeAction.AppActions.resetPushTokensAction,
                    ].map {
                        AKAction(
                            $0.title,
                            style: $0.isDestructive ? .destructive : .default,
                            effect: $0.perform
                        )
                    }

                    await AKActionSheet(
                        title: "Danger Zone",
                        message: "Exercise caution when using these options.",
                        actions: actions
                    ).present(translating: [])
                }
            }

            return .init(title: "Danger Zone", isDestructive: true, perform: dangerZone)
        }

        private static var resetUserDefaultsAction: DevModeAction {
            func resetUserDefaults() {
                @Dependency(\.coreKit.hud) var coreHUD: CoreKit.HUD
                @Dependency(\.userDefaults) var defaults: UserDefaults

                defaults.reset(keeping: UserDefaultsKey.permanentKeys)
                coreHUD.showSuccess(text: "Reset UserDefaults")
            }

            return .init(title: "Reset UserDefaults", perform: resetUserDefaults)
        }

        private static var setCurrentUserIDAction: DevModeAction {
            func setCurrentUserID() {
                Task {
                    @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities
                    @Dependency(\.userDefaults) var defaults: UserDefaults

                    @Persistent(.currentUserID) var currentUserID: String?
                    @Navigator var navigationCoordinator: NavigationCoordinator<RootNavigationService>

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

                        defaults.reset(keeping: UserDefaultsKey.permanentKeys)
                    }

                    currentUserID = input
                    navigationCoordinator.navigate(to: .root(.modal(.splash)))
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

                        defaults.reset(keeping: UserDefaultsKey.permanentKeys)

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

        // MARK: - Danger Zone Actions

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
