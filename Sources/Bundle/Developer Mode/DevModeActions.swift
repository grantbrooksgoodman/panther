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
public extension DevModeAction { // swiftlint:disable:next type_body_length
    struct AppActions: AppSubsystem.Delegates.DevModeAppActionDelegate {
        // MARK: - Properties

        public var appActions: [DevModeAction] {
            var actions = [
                DevModeAction.AppActions.manageBreadcrumbsCaptureAction,
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

        private static var manageBreadcrumbsCaptureAction: DevModeAction {
            func manageBreadcrumbsCapture() {
                Task { @MainActor in
                    @Dependency(\.build) var build: Build

                    @Dependency(\.commonServices.metadata) var metadataService: MetadataService
                    @Dependency(\.uiApplication) var uiApplication: UIApplication
                    @Dependency(\.uiPasteboard) var uiPasteboard: UIPasteboard

                    let clearBreadcrumbsCaptureHistoryAction: AKAction = .init(
                        "Clear Capture History",
                        style: .destructive,
                        effect: AppActions.presentClearBreadcrumbsCaptureHistoryActionSheet
                    )

                    let openHostedBreadcrumbsDirectoryAction: AKAction = .init(
                        "Open Hosted Directory",
                        effect: AppActions.openHostedBreadcrumbsDirectory
                    )

                    await AKActionSheet(
                        title: "Manage Hosted Breadcrumbs Capture",
                        actions: [
                            openHostedBreadcrumbsDirectoryAction,
                            clearBreadcrumbsCaptureHistoryAction,
                        ]
                    ).present(translating: [])
                }
            }

            return .init(
                title: "Manage Breadcrumbs Capture",
                perform: manageBreadcrumbsCapture
            )
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

        // MARK: - Auxiliary

        private static func openHostedBreadcrumbsDirectory() {
            Task { @MainActor in
                @Dependency(\.build) var build: Build
                @Dependency(\.commonServices.metadata) var metadataService: MetadataService
                @Dependency(\.uiApplication) var uiApplication: UIApplication

                guard let storageReferenceURLString = metadataService.storageReferenceURL?.absoluteString,
                      let url = URL(string: [
                          storageReferenceURLString,
                          Networking.config.environment.shortString,
                          NetworkPath.breadcrumbs.rawValue,
                          build.bundleVersion,
                          build.bundleRevision,
                          "\(build.buildNumber)\(build.milestone.shortString)",
                      ].joined(separator: "~2F")) else { return }

                uiApplication.open(url)
            }
        }

        private static func presentClearBreadcrumbsCaptureHistoryActionSheet() {
            Task {
                @Dependency(\.coreKit) var core: CoreKit
                @Dependency(\.networking.storage) var storage: StorageDelegate

                func clearRemoteCaptureHistory() {
                    Task {
                        let isCapturing = AppSubsystem.delegates.breadcrumbsCapture.isCapturing
                        AppSubsystem.delegates.breadcrumbsCapture.stopCapture()

                        core.hud.showProgress(isModal: true)
                        defer {
                            core.hud.hide()
                            if isCapturing { AppSubsystem.delegates.breadcrumbsCapture.startCapture() }
                        }

                        if let exception = await storage.deleteAllItems(
                            at: NetworkPath.breadcrumbs.rawValue,
                            includeItemsInSubdirectories: true,
                            timeout: .seconds(300)
                        ) {
                            Logger.log(exception, with: .toast)
                        } else {
                            core.gcd.after(.seconds(1)) { core.hud.showSuccess() }
                        }
                    }
                }

                @Persistent(.breadcrumbsCaptureHistory) var breadcrumbsCaptureHistory: Set<String>?

                let hostedOnlyAction: AKAction = .init(
                    "Hosted Only",
                    style: .destructive,
                ) { clearRemoteCaptureHistory() }

                let localAndHostedAction: AKAction = .init(
                    "Local and Hosted",
                    style: .destructivePreferred,
                ) {
                    breadcrumbsCaptureHistory = nil
                    clearRemoteCaptureHistory()
                }

                let localOnlyAction: AKAction = .init("Local Only") {
                    breadcrumbsCaptureHistory = nil
                    core.hud.showSuccess()
                }

                await AKActionSheet(
                    title: "Clear Breadcrumbs Capture History",
                    message: "Select the type of history to clear.",
                    actions: [
                        hostedOnlyAction,
                        localOnlyAction,
                        localAndHostedAction,
                    ],
                ).present(translating: [])
            }
        }
    }
}
