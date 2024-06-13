//
//  ConversationCellViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import AlertKit
import CoreArchitecture

public struct ConversationCellViewService {
    // MARK: - Methods

    /// `.deleteConversationButtonTapped`
    /// - Returns: `true` if the user selected the cancel option.
    public func presentDeletionActionSheet(_ title: String) async -> Bool {
        let actionSheet: AKActionSheet = .init(
            title: title,
            message: "Are you sure you'd like to delete this conversation?\nThis operation cannot be undone.",
            actions: [.init(title: "Delete", style: .destructive)],
            shouldTranslate: [.actions(indices: nil), .message]
        )

        let actionID = await actionSheet.present()
        return actionID == -1
    }

    /// `.userInfoBadgeTapped`
    public func presentUserInfoAlert(_ cellViewData: ConversationCellViewData) {
        Task {
            @Dependency(\.build) var build: Build
            @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities
            @Dependency(\.userDefaults) var defaults: UserDefaults
            @Dependency(\.commonServices.regionDetail) var regionDetailService: RegionDetailService

            @Navigator var navigationCoordinator: NavigationCoordinator<RootNavigationService>

            guard let user = cellViewData.otherUser else { return }

            var languageName = user.languageCode.uppercased()
            if let languageExonym = languageName.languageExonym {
                languageName = "\(languageExonym) (\(user.languageCode.uppercased()))"
            }

            @Localized(.language) var languageString: String
            @Localized(.region) var regionString: String

            var actions: [AKAction]?
            if build.developerModeEnabled {
                actions = [.init(title: "Set to Current User", style: .preferred)]
            }

            let alert: AKAlert = .init(
                title: cellViewData.titleLabelText,
                message: "\(languageString): \(languageName)\n\(regionString): \(regionDetailService.localizedRegionName(regionCode: user.phoneNumber.regionCode))",
                actions: actions,
                cancelButtonTitle: Localized(.dismiss).wrappedValue,
                shouldTranslate: [.none]
            )

            let actionID = await alert.present()
            guard actionID != -1 else { return }

            coreUtilities.clearCaches()
            coreUtilities.eraseDocumentsDirectory()
            coreUtilities.eraseTemporaryDirectory()

            defaults.reset(keeping: UserDefaultsKeyDomain.permanentKeys)

            @Persistent(.currentUserID) var currentUserID: String?
            currentUserID = user.id

            navigationCoordinator.navigate(to: .root(.splash))
        }
    }
}
