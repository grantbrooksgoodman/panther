//
//  ConversationCellViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AlertKit
import AppSubsystem

public struct ConversationCellViewService {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.userDefaults) private var defaults: UserDefaults
    @Dependency(\.clientSession.moderation) private var moderationSession: ModerationSessionService
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.commonServices.regionDetail) private var regionDetailService: RegionDetailService

    // MARK: - Methods

    public func blockUsersButtonTapped(_ conversation: Conversation) async -> Exception? {
        await moderationSession.blockUsers(inConversation: conversation)
    }

    /// `.deleteConversationButtonTapped`
    /// - Returns: `true` if the user selected the cancel option.
    public func presentDeletionActionSheet(_ title: String) async -> Bool {
        var cancelled = true

        await AKActionSheet(
            title: title,
            message: "Are you sure you'd like to delete this conversation?\nThis operation cannot be undone.",
            actions: [.init("Delete", style: .destructive) { cancelled = false }],
            cancelButtonTitle: Localized(.cancel).wrappedValue
        ).present(translating: [.actions(), .message])

        return cancelled
    }

    /// `.userInfoBadgeTapped`
    public func presentUserInfoAlert(_ cellViewData: ConversationCellViewData) {
        Task {
            guard let user = cellViewData.otherUser else { return }

            var languageName = user.languageCode.uppercased()
            if let languageExonym = languageName.languageExonym {
                languageName = "\(languageExonym) (\(user.languageCode.uppercased()))"
            }

            @Localized(.language) var languageString: String
            @Localized(.region) var regionString: String

            var actions: [AKAction] = [.cancelAction(title: Localized(.dismiss).wrappedValue)]
            if build.isDeveloperModeEnabled {
                let setToCurrentUserAction: AKAction = .init("Set to Current User", style: .preferred) {
                    coreUtilities.clearCaches()
                    coreUtilities.eraseDocumentsDirectory()
                    coreUtilities.eraseTemporaryDirectory()

                    defaults.reset()

                    @Persistent(.currentUserID) var currentUserID: String?
                    currentUserID = user.id

                    RootSheets.dismiss()
                    navigation.navigate(to: .userContent(.stack([])))
                    navigation.navigate(to: .root(.modal(.splash)))
                }

                actions.append(setToCurrentUserAction)
            }

            await AKAlert(
                title: cellViewData.titleLabelText.isEmpty ? nil : cellViewData.titleLabelText, // swiftlint:disable:next line_length
                message: "\(languageString): \(languageName)\n\(regionString): \(regionDetailService.localizedRegionName(regionCode: user.phoneNumber.regionCode))",
                actions: actions
            ).present(translating: [])
        }
    }

    public func reportUsersButtonTapped(_ conversation: Conversation) async -> Exception? {
        await moderationSession.reportUsers(inConversation: conversation)
    }
}
