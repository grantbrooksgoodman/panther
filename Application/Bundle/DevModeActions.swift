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
import Redux

/**
 Use this extension to add new actions to the Developer Mode menu.
 */
public extension DevModeService {
    // MARK: - Properties

    static var clearCachesAction: DevModeAction {
        func clearCaches() {
            @Dependency(\.coreKit) var core: CoreKit
            core.utils.clearCaches()
            core.hud.flash(image: .success)
        }

        return .init(title: "Clear Caches", perform: clearCaches)
    }

    static var destroyConversationDatabaseAction: DevModeAction {
        func destroyConversationDatabase() {
            @Dependency(\.coreKit) var core: CoreKit
            @Dependency(\.networking.config.environment.description) var networkEnvironment: String

            var confirmationAlert = AKConfirmationAlert(
                title: "Destroy Database", // swiftlint:disable:next line_length
                message: "This will delete all conversations for all users in the \(networkEnvironment.uppercased()) environment.\n\nThis operation cannot be undone.",
                confirmationStyle: .destructivePreferred,
                shouldTranslate: [.none]
            )

            confirmationAlert.present { didConfirm in
                guard didConfirm == 1 else { return }

                confirmationAlert = .init(
                    title: "Are you sure?",
                    message: "ALL CONVERSATIONS FOR ALL USERS WILL BE DELETED!",
                    confirmationStyle: .destructivePreferred,
                    shouldTranslate: [.none]
                )

                confirmationAlert.present { didConfirm in
                    guard didConfirm == 1 else { return }

                    Task {
                        if let exception = await core.utils.destroyConversationDatabase() {
                            Logger.log(exception, with: .toast())
                        } else {
                            core.hud.flash(image: .success)
                        }
                    }
                }
            }
        }

        return .init(title: "Destroy Conversation Database", perform: destroyConversationDatabase, isDestructive: true)
    }

    static var eraseDocumentsDirectoryAction: DevModeAction {
        func eraseDocumentsDirectory() {
            @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities

            AKConfirmationAlert(
                title: "Erase Documents Directory",
                message: "This will remove all files in the userland Documents directory. An app restart is required.",
                confirmationStyle: .destructivePreferred,
                shouldTranslate: [.none]
            ).present { didConfirm in
                guard didConfirm == 1 else { return }

                guard let exception = coreUtilities.eraseDocumentsDirectory() else {
                    AKAlert(
                        message: "The Documents directory has been erased. You must now restart the app.",
                        actions: [.init(title: "Exit", style: .destructivePreferred)],
                        showsCancelButton: false,
                        shouldTranslate: [.none]
                    ).present { _ in
                        exit(0)
                    }
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
            let actions = [
                clearCachesAction,
                eraseDocumentsDirectoryAction,
                eraseTemporaryDirectoryAction,
                setCurrentUserIDAction,
                toggleNetworkActivityIndicatorAction,
                destroyConversationDatabaseAction,
                resetPushTokensAction,
            ]
            let akActions = actions.map { AKAction(title: $0.title, style: $0.isDestructive ? .destructive : .default) }

            let actionSheet = AKActionSheet(
                message: "Custom Options",
                actions: akActions,
                cancelButtonTitle: "Back",
                shouldTranslate: [.none]
            )

            actionSheet.present { actionID in
                guard actionID != -1 else {
                    DevModeService.presentActionSheet()
                    return
                }

                guard let index = akActions.firstIndex(where: { $0.identifier == actionID }),
                      index < actions.count else { return }

                actions[index].perform()
            }
        }

        return .init(title: "Custom Options", perform: presentCustomOptions)
    }

    static var presentStandardOptionsAction: DevModeAction {
        func presentStandardOptions() {
            let akActions = DevModeAction.Standard.available.map { AKAction(title: $0.title, style: $0.isDestructive ? .destructive : .default) }

            let actionSheet = AKActionSheet(
                message: "Standard Options",
                actions: akActions,
                cancelButtonTitle: "Back",
                shouldTranslate: [.none]
            )

            actionSheet.present { actionID in
                guard actionID != -1 else {
                    DevModeService.presentActionSheet()
                    return
                }

                guard let index = akActions.firstIndex(where: { $0.identifier == actionID }),
                      index < DevModeAction.Standard.available.count else { return }

                DevModeAction.Standard.available[index].perform()
            }
        }

        return .init(title: "Standard Options", perform: presentStandardOptions)
    }

    static var resetPushTokensAction: DevModeAction {
        func resetPushTokens() {
            @Dependency(\.coreKit) var core: CoreKit
            @Dependency(\.networking.config.environment.description) var networkEnvironment: String

            AKConfirmationAlert(
                title: "Reset Push Tokens", // swiftlint:disable:next line_length
                message: "This will remove all push tokens for all users in the \(networkEnvironment.uppercased()) environment.\n\nThis operation cannot be undone.",
                confirmationStyle: .destructivePreferred,
                shouldTranslate: [.none]
            ).present { didConfirm in
                guard didConfirm == 1 else { return }

                Task {
                    if let exception = await core.utils.resetPushTokens() {
                        Logger.log(exception, with: .toast())
                    } else {
                        core.hud.flash("Reset Push Tokens", image: .success)
                    }
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
            @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities
            @Dependency(\.rootNavigationCoordinator) var navigationCoordinator: RootNavigationCoordinator
            @Persistent(.currentUserID) var currentUserID: String?

            let textFieldAlert = AKTextFieldAlert(
                message: "Set Current User ID",
                actions: [.init(title: "Done", style: .preferred)],
                textFieldAttributes: [
                    .capitalizationType: UITextAutocapitalizationType.none,
                    .correctionType: UITextAutocorrectionType.no,
                    .textAlignment: NSTextAlignment.center,
                ],
                shouldTranslate: [.none]
            )

            textFieldAlert.presentTextFieldAlert { inputString, actionID in
                guard actionID != -1,
                      let inputString,
                      !inputString.isBlank else { return }
                let previousValue = currentUserID
                currentUserID = inputString
                if currentUserID != previousValue {
                    coreUtilities.clearCaches()
                }

                navigationCoordinator.setPage(.splash)
            }
        }

        return .init(title: "Set Current User ID", perform: setCurrentUserID)
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
