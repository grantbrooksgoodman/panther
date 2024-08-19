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

/* 3rd-party */
import AlertKit
import CoreArchitecture

/**
 Use this extension to add new actions to the Developer Mode menu.
 */
public extension DevModeService {
    // MARK: - Properties

    static var destroyConversationDatabaseAction: DevModeAction {
        func destroyConversationDatabase() {
            Task {
                @Dependency(\.coreKit) var core: CoreKit
                @Dependency(\.networking.config.environment.description) var networkEnvironment: String

                let confirmed = await AKConfirmationAlert(
                    title: "Destroy Database", // swiftlint:disable:next line_length
                    message: "This will delete all conversations for all users in the \(networkEnvironment.uppercased()) environment.\n\nThis operation cannot be undone.",
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

        return .init(title: "Destroy Conversation Database", perform: destroyConversationDatabase, isDestructive: true)
    }

    static var eraseDocumentsDirectoryAction: DevModeAction {
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

    static var eraseTemporaryDirectoryAction: DevModeAction {
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

    static var presentCustomOptionsAction: DevModeAction {
        func presentCustomOptions() {
            Task {
                let actions = [
                    eraseDocumentsDirectoryAction,
                    eraseTemporaryDirectoryAction,
                    setCurrentUserIDAction,
                    switchEnvironmentAction,
                    toggleNetworkActivityIndicatorAction,
                    destroyConversationDatabaseAction,
                    resetPushTokensAction,
                ]

                var akActions = actions.map { devModeAction in
                    AKAction(devModeAction.title, style: devModeAction.isDestructive ? .destructive : .default) {
                        devModeAction.perform()
                    }
                }

                akActions.append(.init("Back", style: .cancel) { DevModeService.presentActionSheet() })

                await AKActionSheet(
                    title: "Custom Options",
                    actions: akActions
                ).present(translating: [])
            }
        }

        return .init(title: "Custom Options", perform: presentCustomOptions)
    }

    static var presentStandardOptionsAction: DevModeAction {
        func presentStandardOptions() {
            Task {
                var akActions = DevModeAction.Standard.available.map { devModeAction in
                    AKAction(devModeAction.title, style: devModeAction.isDestructive ? .destructive : .default) {
                        devModeAction.perform()
                    }
                }

                akActions.append(.init("Back", style: .cancel) { DevModeService.presentActionSheet() })

                await AKActionSheet(
                    title: "Standard Options",
                    actions: akActions
                ).present(translating: [])
            }
        }

        return .init(title: "Standard Options", perform: presentStandardOptions)
    }

    static var resetPushTokensAction: DevModeAction {
        func resetPushTokens() {
            Task {
                @Dependency(\.coreKit) var core: CoreKit
                @Dependency(\.networking.config.environment.description) var networkEnvironment: String

                let confirmed = await AKConfirmationAlert(
                    title: "Reset Push Tokens", // swiftlint:disable:next line_length
                    message: "This will remove all push tokens for all users in the \(networkEnvironment.uppercased()) environment.\n\nThis operation cannot be undone.",
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
            perform: resetPushTokens,
            isDestructive: true
        )
    }

    static var setCurrentUserIDAction: DevModeAction {
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

                    defaults.reset(keeping: UserDefaultsKeyDomain.permanentKeys)
                }

                currentUserID = input
                navigationCoordinator.navigate(to: .root(.modal(.splash)))
            }
        }

        return .init(title: "Set Current User ID", perform: setCurrentUserID)
    }

    static var switchEnvironmentAction: DevModeAction {
        func switchEnvironment() {
            Task {
                @Sendable
                func switchTo(_ environment: NetworkEnvironment) async {
                    @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities
                    @Dependency(\.userDefaults) var defaults: UserDefaults

                    @Persistent(.networkEnvironment) var persistentEnvironment: NetworkEnvironment?

                    persistentEnvironment = environment

                    coreUtilities.clearCaches()
                    coreUtilities.eraseDocumentsDirectory()
                    coreUtilities.eraseTemporaryDirectory()

                    defaults.reset(keeping: UserDefaultsKeyDomain.permanentKeys)

                    let environmentString = (persistentEnvironment ?? .production).description

                    await AKAlert(
                        message: "Switched to \(environmentString) environment. You must now restart the app.",
                        actions: [.init("Exit", style: .destructivePreferred, effect: { exit(0) })]
                    ).present(translating: [])
                }

                @Dependency(\.networking.config.environment) var networkEnvironment: NetworkEnvironment

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
                switch networkEnvironment {
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
                    title: "Switch from \(networkEnvironment.description) Environment",
                    actions: actions
                ).present(translating: [])
            }
        }

        return .init(title: "Switch Environment", perform: switchEnvironment)
    }

    static var toggleNetworkActivityIndicatorAction: DevModeAction {
        func toggleNetworkActivityIndicator() {
            @Dependency(\.coreKit.hud) var coreHUD: CoreKit.HUD
            @Persistent(.indicatesNetworkActivity) var defaultsValue: Bool?

            guard let value = defaultsValue else {
                defaultsValue = true
                coreHUD.showSuccess(text: "ON")
                return
            }

            defaultsValue = !value
            coreHUD.showSuccess(text: !value == true ? "ON" : "OFF")
        }

        return .init(
            title: "Toggle Network Activity Indicator",
            perform: toggleNetworkActivityIndicator
        )
    }

    // MARK: - Custom Action Addition

    static func addCustomActions() {
        /* Add custom DevModeAction implementations here. */
        addActions([presentCustomOptionsAction, presentStandardOptionsAction])
    }
}

public extension Persistent {
    convenience init(_ devModeServiceKey: UserDefaultsKeyDomain.DevModeServiceDefaultsKey) {
        self.init(.app(.devModeService(devModeServiceKey)))
    }
}

public extension UserDefaultsKeyDomain {
    enum DevModeServiceDefaultsKey: String {
        case indicatesNetworkActivity
    }
}
