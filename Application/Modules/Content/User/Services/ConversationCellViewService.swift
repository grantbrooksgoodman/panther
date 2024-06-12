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
    // MARK: - Dependencies

    @Dependency(\.commonServices.regionDetail) private var regionDetailService: RegionDetailService

    // MARK: - Methods

    /// `.deleteConversationButtonTapped`
    /// - Returns: `true` if the user selected the cancel option.
    public func presentDeletionActionSheet(_ title: String) async -> Bool {
        let actionSheet: AKActionSheet = .init(
            title: title,
            message: "Are you sure you'd like to delete this conversation?\nThis operation cannot be undone.",
            actions: [.init(title: "Delete", style: .destructive)],
            shouldTranslate: [.actions(indices: nil), .message],
            networkDependent: true
        )

        let actionID = await actionSheet.present()
        return actionID == -1
    }

    /// `.userInfoBadgeTapped`
    public func presentUserInfoAlert(_ cellViewData: ConversationCellViewData) {
        guard let user = cellViewData.otherUser else { return }

        var languageName = user.languageCode.uppercased()
        if let languageExonym = languageName.languageExonym {
            languageName = "\(languageExonym) (\(user.languageCode.uppercased()))"
        }

        @Localized(.language) var languageString: String
        @Localized(.region) var regionString: String

        let alert: AKAlert = .init(
            title: cellViewData.titleLabelText,
            message: "\(languageString): \(languageName)\n\(regionString): \(regionDetailService.localizedRegionName(regionCode: user.phoneNumber.regionCode))",
            cancelButtonTitle: Localized(.dismiss).wrappedValue,
            shouldTranslate: [.none]
        )

        Task { await alert.present() }
    }
}
