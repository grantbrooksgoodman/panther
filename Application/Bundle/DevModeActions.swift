//
//  DevModeActions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

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
                        fatalError()
                    }
                    return
                }

                AKErrorAlert(error: .init(exception)).present()
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
                toggleNetworkActivityIndicatorAction,
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
