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
        // MARK: - Dependencies

        @Dependency(\.mainBundle) private var mainBundle: Bundle

        // MARK: - Properties

        /// The actions to display in the Developer Mode action sheet.
        var appActions: [DevModeAction] {
            var actions = [
                AppActions.DatabaseOptions.databaseOptionsAction,
                AppActions.UIOptions.uiOptionsAction,
                AppActions.UserOptions.userOptionsAction,
                AppActions.dangerZoneAction,
            ]

            if Networking.config.environment != .production,
               mainBundle.containsStagingAssets {
                actions.insert(
                    AppActions.stagingModeOptionsAction,
                    at: 2
                )
            }

            return actions
        }

        // MARK: - Methods

        static func presentActionSheet() {
            Task { @MainActor in
                let instance = AppActions()
                var actions = instance.appActions.map { devModeAction in
                    AKAction(
                        devModeAction.title,
                        style: devModeAction.isDestructive ? .destructive : .default
                    ) {
                        devModeAction.perform()
                    }
                }

                if !instance.appActions.isEmpty {
                    actions.append(
                        AKAction(
                            "Back",
                            style: .cancel
                        ) {
                            DevModeService.presentActionSheet()
                        }
                    )
                }

                await AKActionSheet(
                    title: "Developer Mode Options",
                    actions: actions
                ).present(translating: [])
            }
        }

        // MARK: - Top-level Actions

        private static let dangerZoneAction: DevModeAction = {
            @Sendable
            func dangerZone() {
                Task {
                    @Dependency(\.clientSession.entity.user.currentUser) var currentUser: User?

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

            return DevModeAction(
                title: "Danger Zone",
                isDestructive: true,
                perform: dangerZone
            )
        }()

        private static let stagingModeOptionsAction: DevModeAction = {
            @Sendable
            func stagingModeOptions() { // swiftlint:disable:next identifier_name
                @Dependency(\.networking.conversationService.staging) var _conversationStagingService: ConversationStagingService
                let conversationStagingService = LockIsolated(_conversationStagingService)

                Task { @MainActor in
                    @Dependency(\.coreKit.hud) var coreHUD: CoreKit.HUD
                    @Dependency(\.clientSession.entity.user.currentUser) var currentUser: User?

                    @Persistent(.isInStagingMode) var isInStagingMode: Bool?
                    let stageConversationsAction = AKAction(
                        "Stage Conversations",
                        isEnabled: isInStagingMode == true
                    ) {
                        Task { @MainActor in
                            guard await AKConfirmationAlert(
                                title: "Stage Conversations",
                                message: "All conversations for the current user will be deleted and staged versions created for App Store mockup creation."
                            ).present(translating: []) else { return }

                            do throws(Exception) {
                                try await conversationStagingService
                                    .wrappedValue
                                    .stageConversations()
                            } catch {
                                Logger.log(
                                    error,
                                    with: .toast
                                )
                            }
                        }
                    }

                    let toggleStagingModeAction = AKAction(
                        "\(isInStagingMode == true ? "Disable" : "Enable") Staging Mode",
                        style: isInStagingMode == true ? .destructivePreferred : .preferred
                    ) {
                        @Persistent(.isInStagingMode) var isInStagingMode: Bool?
                        isInStagingMode = isInStagingMode == true ? nil : true
                        coreHUD.showSuccess(
                            text: "Staging Mode \(isInStagingMode == true ? "Enabled" : "Disabled")"
                        )
                    }

                    await AKActionSheet(
                        title: "Staging Mode Options",
                        actions: [
                            currentUser == nil ? nil : stageConversationsAction,
                            toggleStagingModeAction,
                        ].compactMap(\.self)
                    ).present(translating: [])
                }
            }

            return DevModeAction(
                title: "Staging Mode Options",
                perform: stagingModeOptions
            )
        }()
    }
}
