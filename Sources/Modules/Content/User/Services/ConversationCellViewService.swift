//
//  ConversationCellViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem

/// The service that handles conversation cell interactions requiring presentation or session
/// work.
///
/// ``ConversationCellReducer`` delegates to this service for blocking, reporting, deletion
/// confirmation, and user info presentation.
struct ConversationCellViewService {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.clientSession.entity.moderation) private var moderationSession: ModerationSessionService
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.commonServices.regionDetail) private var regionDetailService: RegionDetailService
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Methods

    /// Begins the block users flow for the given conversation.
    ///
    /// - Parameter conversation: The conversation whose users to block.
    ///
    /// - Throws: An `Exception` if the operation fails.
    func blockUsersButtonTapped(
        _ conversation: Conversation
    ) async throws(Exception) {
        try await moderationSession.blockUsers(
            inConversation: conversation
        )
    }

    /// Presents the deletion confirmation action sheet for a conversation.
    ///
    /// - Parameter title: The conversation title the action sheet displays.
    ///
    /// - Returns: `true` if the user canceled the deletion; otherwise, `false`.
    func presentDeletionActionSheet(_ title: String) async -> Bool {
        let cancelled = LockIsolated(true)
        let deleteAction: AKAction = .init(
            "Delete",
            style: .destructive
        ) {
            cancelled.wrappedValue = false
        }

        await AKActionSheet(
            title: title,
            message: "Are you sure you'd like to delete this conversation?\nThis operation cannot be undone.",
            actions: [deleteAction],
            cancelButtonTitle: Localized(.cancel).wrappedValue
        ).present(translating: [
            .actions(),
            .message,
        ])

        return cancelled.wrappedValue
    }

    /// Presents an alert with information about the given user.
    ///
    /// The alert shows the user's language and region. In developer mode, an additional action
    /// switches the current account to the given user, resetting the app and returning to the
    /// splash page.
    ///
    /// - Parameter user: The user the alert describes.
    func presentUserInfoAlert(
        _ user: User
    ) {
        Task { @MainActor in
            var languageName = user.languageCode.uppercased()
            if let languageExonym = languageName.languageExonym {
                languageName = "\(languageExonym) (\(user.languageCode.uppercased()))"
            }

            @Localized(.language) var languageString: String
            @Localized(.region) var regionString: String

            let regionName = regionDetailService.localizedRegionName(
                regionCode: user.phoneNumber.regionCode
            )

            var actions: [AKAction] = [.cancelAction(title: Localized(.dismiss).wrappedValue)]
            if build.isDeveloperModeEnabled {
                let setToCurrentUserAction: AKAction = .init(
                    "Set to Current User",
                    style: .preferred
                ) {
                    Task { @MainActor in
                        RuntimeStorage.store(
                            false,
                            as: .shouldNotifyOfConversationAvailability
                        )

                        Application.reset()
                        Application.dismissSheets()

                        @Persistent(.currentUserID) var currentUserID: String?
                        currentUserID = user.id

                        navigation.navigate(to: .userContent(.stack([])))
                        navigation.navigate(to: .root(.modal(.splash)))
                    }
                }

                actions.append(setToCurrentUserAction)
            }

            let alertMessage = "\(languageString): \(languageName)\n\(regionString): \(regionName)"
            if UIApplication.isFullyV26Compatible {
                let matchingLabels = uiApplication
                    .presentedViews
                    .compactMap { $0 as? UILabel }
                    .filter { $0.tag == user.languageCode.uppercased().hashValue }

                await AKActionSheet(
                    title: user.displayName,
                    message: alertMessage,
                    actions: actions,
                    cancelButtonTitle: Localized(.cancel).wrappedValue,
                    sourceItem: .custom(.view(
                        matchingLabels.count > 1 ? nil : matchingLabels.first
                    ))
                ).present(translating: [])
            } else {
                await AKAlert(
                    title: user.displayName,
                    message: alertMessage,
                    actions: actions
                ).present(translating: [])
            }
        }
    }

    /// Begins the report users flow for the given conversation.
    ///
    /// - Parameter conversation: The conversation whose users to report.
    ///
    /// - Throws: An `Exception` if the operation fails.
    func reportUsersButtonTapped(
        _ conversation: Conversation
    ) async throws(Exception) {
        try await moderationSession.reportUsers(
            inConversation: conversation
        )
    }
}
