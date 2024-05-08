//
//  SettingsContentPageView+StaticListItems.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

public extension SettingsContentPageView {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.SettingsPageView
    private typealias Strings = AppConstants.Strings.SettingsPageView

    // MARK: - Properties

    var changeThemeListItem: StaticListItem {
        .init(
            title: viewModel.strings.value(for: .changeThemeButtonText),
            imageData: (.init(systemName: Strings.changeThemeButtonImageSystemName), Colors.changeThemeButtonImageForeground),
            action: { viewModel.send(.changeThemeButtonTapped) }
        )
    }

    var clearCachesListItem: StaticListItem {
        .init(
            title: viewModel.strings.value(for: .clearCachesButtonText),
            imageData: (.init(systemName: Strings.clearCachesButtonImageSystemName), Colors.clearCachesButtonImageForeground),
            action: { viewModel.send(.clearCachesButtonTapped) }
        )
    }

    var deleteAccountListItem: StaticListItem {
        .init(
            title: viewModel.strings.value(for: .deleteAccountButtonText),
            imageData: (.init(systemName: Strings.deleteAccountButtonImageSystemName), Colors.deleteAccountButtonImageForeground),
            action: { viewModel.send(.deleteAccountButtonTapped) }
        )
    }

    var inviteFriendsListItem: StaticListItem {
        .init(
            title: viewModel.strings.value(for: .inviteFriendsButtonText),
            imageData: (.init(systemName: Strings.inviteFriendsButtonImageSystemName), Colors.inviteFriendsButtonImageForeground),
            action: { viewModel.send(.inviteFriendsButtonTapped) }
        )
    }

    var leaveReviewListItem: StaticListItem {
        .init(
            title: viewModel.strings.value(for: .leaveAReviewButtonText),
            imageData: (.init(systemName: Strings.leaveReviewButtonImageSystemName), Colors.leaveReviewButtonImageForeground),
            action: { viewModel.send(.leaveReviewButtonTapped) }
        )
    }

    var sendFeedbackListItem: StaticListItem {
        .init(
            title: Localized(.sendFeedback).wrappedValue,
            imageData: (.init(systemName: Strings.sendFeedbackButtonImageSystemName), Colors.sendFeedbackButtonImageForeground),
            action: { viewModel.send(.sendFeedbackButtonTapped) }
        )
    }

    var signOutListItem: StaticListItem {
        .init(
            title: viewModel.strings.value(for: .signOutButtonText),
            imageData: (.init(systemName: Strings.signOutButtonImageSystemName), Colors.signOutButtonImageForeground),
            action: { viewModel.send(.signOutButtonTapped) }
        )
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.SettingsPageViewStringKey) -> String {
        (first(where: { $0.key == .settingsPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
