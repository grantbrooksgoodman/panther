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

extension DevModeAction.AppActions {
    enum DangerZone {
        private enum Action {
            /* MARK: Cases */

            case clearPreviousLanguageCodes // swiftlint:disable identifier_name
            case deleteConversationsInvisibleToCurrentUser
            case deleteCurrentUserConversations
            case deleteGroupChatsWithoutNameOrPhoto
            case deleteMRCConversations
            case deleteOneToOneConversationsWithFewerThanFiveMessages
            case deletePenPalsConversations // swiftlint:enable identifier_name
            case destroyConversationDatabase
            case resetPushTokens

            /* MARK: Properties */

            fileprivate var confirmationAlertTitle: String {
                switch self {
                case .clearPreviousLanguageCodes: "Clear Previous Language Codes"
                case .deleteConversationsInvisibleToCurrentUser: "Delete Conversations Invisible to Current User"
                case .deleteCurrentUserConversations: "Delete Current User Conversations"
                case .deleteGroupChatsWithoutNameOrPhoto: "Delete Group Chats Without Name or Photo"
                case .deleteMRCConversations: "Delete MRC Conversations"
                case .deleteOneToOneConversationsWithFewerThanFiveMessages: "Delete 1:1 Conversations with <5 Messages"
                case .deletePenPalsConversations: "Delete PenPals Conversations"
                case .destroyConversationDatabase: "Destroy Conversation Database"
                case .resetPushTokens: "Reset Push Tokens"
                }
            }

            fileprivate var confirmationAlertMessage: String {
                switch self { // swiftlint:disable line_length
                case .clearPreviousLanguageCodes: "This will clear all previous language code history for the current user.\n\nThis operation cannot be undone."
                case .deleteConversationsInvisibleToCurrentUser: "This will delete all conversations that are not visible to the current user.\n\nThis operation cannot be undone."
                case .deleteCurrentUserConversations: "This will delete all conversations for the current user.\n\nThis operation cannot be undone."
                case .deleteGroupChatsWithoutNameOrPhoto: "This will delete all group chats without a name or photo attached to their metadata.\n\nThis operation cannot be undone."
                case .deleteMRCConversations: "This will delete all Message Recipient Consent-enabled conversations for the current user.\n\nThis operation cannot be undone."
                case .deleteOneToOneConversationsWithFewerThanFiveMessages: "This will delete all 1:1 conversations with fewer than 5 messages.\n\nThis operation cannot be undone."
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
            @Sendable
            func deleteConversations() {
                Task {
                    @Dependency(\.clientSession) var clientSession: ClientSession

                    let ignoredConversationIDKeys = clientSession.store.ignoredConversationIDKeys

                    let allForCurrentUserCount = (
                        (clientSession.entity.user.currentUser?.conversationIDs?.map(\.key) ?? []) +
                            ignoredConversationIDKeys
                    ).unique.count

                    var actions: [DevModeAction] = [
                        .init(
                            title: "All for Current User (\(allForCurrentUserCount))",
                            isDestructive: true
                        ) { performAction(.deleteCurrentUserConversations) },
                    ]

                    guard let conversations = clientSession.entity.user.currentUser?.conversations else { return }

                    let invisibleToCurrentUserCount = (
                        conversations
                            .filter { !$0.isVisibleForCurrentUser }
                            .map(\.id.key) + ignoredConversationIDKeys
                    ).unique.count

                    let groupChatsWithoutNameOrPhotoCount = conversations.filter {
                        $0.metadata.name.isBangQualifiedEmpty &&
                            $0.metadata.imageData == nil &&
                            !$0.metadata.isPenPalsConversation &&
                            $0.participants.count > 2
                    }.count

                    let messageRecipientConsentEnabledCount = conversations.filter {
                        $0.didSendConsentMessage ||
                            $0.messages?.contains(where: \.isConsentMessage) == true ||
                            $0.metadata.requiresConsentFromInitiator != nil
                    }.count

                    let oneToOneAndFewerThanFiveMessagesCount = conversations.filter {
                        $0.messageIDs.count < 5 &&
                            $0.participants.count == 2
                    }.count

                    let penPalsCount = conversations.filter(\.metadata.isPenPalsConversation).count

                    if invisibleToCurrentUserCount > 0 {
                        actions.append(
                            .init(
                                title: "Not Visible to Current User (\(invisibleToCurrentUserCount))",
                                isDestructive: true
                            ) { performAction(.deleteConversationsInvisibleToCurrentUser) }
                        )
                    }

                    if groupChatsWithoutNameOrPhotoCount > 0 {
                        actions.append(
                            .init(
                                title: "Group Chats w/o Name or Photo (\(groupChatsWithoutNameOrPhotoCount))",
                                isDestructive: true
                            ) { performAction(.deleteGroupChatsWithoutNameOrPhoto) }
                        )
                    }

                    if messageRecipientConsentEnabledCount > 0 {
                        actions.append(
                            .init(
                                title: "MRC-enabled Conversations (\(messageRecipientConsentEnabledCount))",
                                isDestructive: true
                            ) { performAction(.deleteMRCConversations) }
                        )
                    }

                    if oneToOneAndFewerThanFiveMessagesCount > 0 {
                        actions.append(
                            .init(
                                title: "1:1 Conversations with <5 Messages (\(oneToOneAndFewerThanFiveMessagesCount))",
                                isDestructive: true
                            ) { performAction(.deleteOneToOneConversationsWithFewerThanFiveMessages) }
                        )
                    }

                    if penPalsCount > 0 {
                        actions.append(
                            .init(
                                title: "PenPals Conversations (\(penPalsCount))",
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

            return DevModeAction(
                title: "Delete Conversations",
                isDestructive: true,
                perform: deleteConversations
            )
        }

        static var destroyConversationDatabaseAction: DevModeAction {
            DevModeAction(
                title: Action.destroyConversationDatabase.confirmationAlertTitle,
                isDestructive: true
            ) { performAction(.destroyConversationDatabase) }
        }

        static var resetPushTokensAction: DevModeAction {
            DevModeAction(
                title: Action.resetPushTokens.confirmationAlertTitle,
                isDestructive: true
            ) { performAction(.resetPushTokens) }
        }

        // MARK: - Auxiliary

        private static func performAction(_ action: Action) {
            Task {
                do throws(Exception) {
                    try await _performAction(action)
                } catch {
                    Logger.log(
                        error,
                        with: .toast
                    )
                }
            }
        }

        private static func _performAction(_ action: Action) async throws(Exception) {
            @Dependency(\.coreKit) var core: CoreKit
            @Dependency(\.clientSession.entity.user) var userSession: UserSessionService

            func showSuccessAndReset() {
                core.hud.flash(image: .success)
                Task.delayed(by: .seconds(1)) { @MainActor in
                    Application.reset(
                        preserveCurrentUserID: true,
                        onCompletion: .navigateToSplash
                    )
                }
            }

            guard await AKConfirmationAlert(
                title: action.confirmationAlertTitle,
                message: action.confirmationAlertMessage,
                confirmButtonStyle: .destructivePreferred
            ).present(translating: []) else { return }

            switch action {
            case .clearPreviousLanguageCodes:
                try await core.utils.clearPreviousLanguageCodes()
                core.hud.flash(
                    "Cleared Previous Language Codes",
                    image: .success
                )

            case .deleteConversationsInvisibleToCurrentUser:
                try await core.utils.deleteConversations(
                    .notVisibleForCurrentUser
                )

                showSuccessAndReset()

            case .deleteCurrentUserConversations:
                try await core.utils.deleteConversations(
                    .allForCurrentUser
                )

                showSuccessAndReset()

            case .deleteGroupChatsWithoutNameOrPhoto:
                try await core.utils.deleteConversations(
                    .groupChatsWithoutNameOrPhoto
                )

                showSuccessAndReset()

            case .deleteMRCConversations:
                try await core.utils.deleteConversations(
                    .messageRecipientConsentEnabled
                )

                showSuccessAndReset()

            case .deleteOneToOneConversationsWithFewerThanFiveMessages:
                try await core.utils.deleteConversations(
                    .oneToOneAndFewerThanFiveMessages
                )

                showSuccessAndReset()

            case .deletePenPalsConversations:
                try await core.utils.deleteConversations(
                    .penPals
                )

                showSuccessAndReset()

            case .destroyConversationDatabase:
                guard await AKConfirmationAlert(
                    title: "Are you sure?",
                    message: "ALL CONVERSATIONS FOR ALL USERS WILL BE DELETED!",
                    confirmButtonStyle: .destructivePreferred
                ).present(translating: []) else { return }

                try await core.utils.destroyConversationDatabase()
                showSuccessAndReset()

            case .resetPushTokens:
                try await core.utils.resetPushTokens()
                core.hud.flash(
                    "Reset Push Tokens",
                    image: .success
                )
            }
        }
    }
}
