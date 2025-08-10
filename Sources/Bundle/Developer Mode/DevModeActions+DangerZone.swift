//
//  DevModeActions+DangerZone.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 06/08/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

public extension DevModeAction.AppActions {
    enum DangerZone {
        private enum Action {
            /* MARK: Cases */

            case clearPreviousLanguageCodes
            case deleteCurrentUserConversations
            case deleteMRCConversations
            case deletePenPalsConversations
            case destroyConversationDatabase
            case resetPushTokens

            /* MARK: Properties */

            fileprivate var confirmationAlertTitle: String {
                switch self {
                case .clearPreviousLanguageCodes: "Clear Previous Language Codes"
                case .deleteCurrentUserConversations: "Delete Current User Conversations"
                case .deleteMRCConversations: "Delete MRC Conversations"
                case .deletePenPalsConversations: "Delete PenPals Conversations"
                case .destroyConversationDatabase: "Destroy Conversation Database"
                case .resetPushTokens: "Reset Push Tokens"
                }
            }

            fileprivate var confirmationAlertMessage: String {
                switch self { // swiftlint:disable line_length
                case .clearPreviousLanguageCodes: "This will clear all previous language code history for the current user.\n\nThis operation cannot be undone."
                case .deleteCurrentUserConversations: "This will delete all conversations for the current user.\n\nThis operation cannot be undone."
                case .deleteMRCConversations: "This will delete all Message Recipient Consent-enabled conversations for the current user.\n\nThis operation cannot be undone."
                case .deletePenPalsConversations: "This will delete all PenPals conversations for the current user.\n\nThis operation cannot be undone."
                case .destroyConversationDatabase: "This will delete all conversations for all users in the \(Networking.config.environment.description.uppercased()) environment.\n\nThis operation cannot be undone."
                case .resetPushTokens: "This will remove all push tokens for all users in the \(Networking.config.environment.description.uppercased()) environment.\n\nThis operation cannot be undone."
                    // swiftlint:enable line_length
                }
            }
        }

        // MARK: - Actions

        static var clearPreviousLanguageCodesAction: DevModeAction {
            .init(
                title: Action.clearPreviousLanguageCodes.confirmationAlertTitle,
                isDestructive: true
            ) { performAction(.clearPreviousLanguageCodes) }
        }

        static var deleteConversationsAction: DevModeAction {
            func deleteConversations() {
                Task {
                    @Dependency(\.clientSession.user.currentUser) var currentUser: User?

                    var actions: [DevModeAction] = [
                        .init(
                            title: "All for Current User",
                            isDestructive: true
                        ) { performAction(.deleteCurrentUserConversations) },
                    ]

                    if currentUser?
                        .conversations?
                        .filter({
                            $0.didSendConsentMessage ||
                                $0.messages?.contains(where: \.isConsentMessage) == true ||
                                $0.metadata.requiresConsentFromInitiator != nil
                        }).isEmpty == false {
                        actions.append(
                            .init(
                                title: "MRC-enabled Conversations",
                                isDestructive: true
                            ) { performAction(.deleteMRCConversations) }
                        )
                    }

                    if currentUser?
                        .conversations?
                        .filter(\.metadata.isPenPalsConversation)
                        .isEmpty == false {
                        actions.append(
                            .init(
                                title: "PenPals Conversations",
                                isDestructive: true
                            ) { performAction(.deletePenPalsConversations) }
                        )
                    }

                    await AKActionSheet(
                        title: "Delete Conversations",
                        message: "Select the granularity of conversations to delete.",
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

            return .init(
                title: "Delete Conversations",
                isDestructive: true,
                perform: deleteConversations
            )
        }

        static var destroyConversationDatabaseAction: DevModeAction {
            .init(
                title: Action.destroyConversationDatabase.confirmationAlertTitle,
                isDestructive: true
            ) { performAction(.destroyConversationDatabase) }
        }

        static var resetPushTokensAction: DevModeAction {
            .init(
                title: Action.resetPushTokens.confirmationAlertTitle,
                isDestructive: true
            ) { performAction(.resetPushTokens) }
        }

        // MARK: - Auxiliary

        private static func performAction(_ action: Action) {
            Task { @MainActor in
                @Dependency(\.coreKit) var core: CoreKit
                @Dependency(\.clientSession.user) var userSession: UserSessionService

                guard await AKConfirmationAlert(
                    title: action.confirmationAlertTitle,
                    message: action.confirmationAlertMessage,
                    confirmButtonStyle: .destructivePreferred
                ).present(translating: []) else { return }

                switch action {
                case .clearPreviousLanguageCodes:
                    if let exception = await core.utils.clearPreviousLanguageCodes() {
                        Logger.log(exception, with: .toast)
                    } else {
                        core.hud.flash(image: .success)
                    }

                case .deleteCurrentUserConversations:
                    userSession.stopObservingCurrentUserChanges()

                    if let exception = await core.utils.deleteConversations(.allForCurrentUser) {
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

                case .deleteMRCConversations:
                    userSession.stopObservingCurrentUserChanges()

                    if let exception = await core.utils.deleteConversations(.messageRecipientConsentEnabled) {
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

                case .deletePenPalsConversations:
                    userSession.stopObservingCurrentUserChanges()

                    if let exception = await core.utils.deleteConversations(.penPals) {
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

                case .destroyConversationDatabase:
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

                case .resetPushTokens:
                    if let exception = await core.utils.resetPushTokens() {
                        Logger.log(exception, with: .toast)
                    } else {
                        core.hud.flash("Reset Push Tokens", image: .success)
                    }
                }
            }
        }
    }
}
