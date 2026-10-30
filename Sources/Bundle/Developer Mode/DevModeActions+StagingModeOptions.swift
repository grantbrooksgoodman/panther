//
//  DevModeActions+StagingModeOptions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 28/10/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

extension DevModeAction.AppActions {
    enum StagingModeOptions {
        // MARK: - Properties

        /// The destination that pushes the staging mode options page. Its actions reflect the
        /// app's current state.
        @MainActor
        static var action: DevModeAction {
            @Dependency(\.clientSession.entity.user.currentUser) var currentUser: User?
            @Persistent(.isInStagingMode) var isInStagingMode: Bool?

            var actions = [toggleStagingModeAction]
            if currentUser != nil,
               isInStagingMode == true {
                actions.insert(stageConversationsAction, at: 0)
            }

            return .init(
                title: "Staging Mode Options",
                iconConfiguration: .init(
                    backgroundColor: .purple,
                    overlay: .symbol(name: "theatermasks.fill")
                ),
                destination: actions
            )
        }

        private static let stageConversationsAction: DevModeAction = {
            @Sendable
            func stageConversations() { // swiftlint:disable:next identifier_name
                @Dependency(\.networking.conversationService.staging) var _conversationStagingService: ConversationStagingService
                let conversationStagingService = UncheckedSendable(_conversationStagingService)

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

            return DevModeAction(
                title: "Stage Conversations",
                iconConfiguration: .init(
                    backgroundColor: .mint,
                    overlay: .symbol(name: "square.stack.3d.up.fill")
                ),
                perform: stageConversations
            )
        }()

        private static var toggleStagingModeAction: DevModeAction {
            @Sendable
            func toggleStagingMode() {
                @Dependency(\.coreKit.hud) var coreHUD: CoreKit.HUD
                @Persistent(.isInStagingMode) var isInStagingMode: Bool?
                isInStagingMode = isInStagingMode == true ? nil : true
                coreHUD.showSuccess(
                    text: "Staging Mode \(isInStagingMode == true ? "Enabled" : "Disabled")"
                )
            }

            @Persistent(.isInStagingMode) var isInStagingMode: Bool?
            return .init(
                title: "Staging Mode",
                iconConfiguration: .init(
                    backgroundColor: .purple,
                    overlay: .symbol(name: "wand.and.stars")
                ),
                interaction: .switch(isOn: isInStagingMode == true),
                perform: toggleStagingMode
            )
        }
    }
}
