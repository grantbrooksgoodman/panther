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

struct ConversationCellViewService {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.clientSession.entity.moderation) private var moderationSession: ModerationSessionService
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.commonServices.regionDetail) private var regionDetailService: RegionDetailService
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Methods

    func blockUsersButtonTapped(
        _ conversation: Conversation
    ) async throws(Exception) {
        try await moderationSession.blockUsers(
            inConversation: conversation
        )
    }

    /// `.deleteConversationButtonTapped`
    /// - Returns: `true` if the user selected the cancel option.
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

    /// `.userInfoBadgeTapped`
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

    func reportUsersButtonTapped(
        _ conversation: Conversation
    ) async throws(Exception) {
        try await moderationSession.reportUsers(
            inConversation: conversation
        )
    }
}
