//
//  SettingsContentPageView+GroupedListItems.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

public extension SettingsContentPageView {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.SettingsPageView
    private typealias Floats = AppConstants.CGFloats.SettingsPageView
    private typealias Strings = AppConstants.Strings.SettingsPageView

    // MARK: - Properties

    var blockedUsersListItem: ListRowView.Configuration {
        .init(
            .button { viewModel.send(.blockedUsersButtonTapped) },
            innerText: viewModel.blockedUsersButtonText,
            isEnabled: viewModel.isBlockedUsersButtonEnabled,
            imageView: {
                SquareIconView(
                    .init(
                        backgroundColor: Colors.blockedUsersButtonImageBackground,
                        overlaySymbolName: Strings.blockedUsersButtonImageSystemName
                    )
                )
            }
        )
    }

    var changeThemeListItem: ListRowView.Configuration {
        .init(
            .button { viewModel.send(.changeThemeButtonTapped) },
            innerText: viewModel.strings.value(for: .changeThemeButtonText),
            imageView: {
                SquareIconView(
                    .init(
                        backgroundColor: Colors.changeThemeButtonImageBackground,
                        overlayFramePercentOfTotalSize: Floats.changeThemeButtonOverlayFramePercentOfTotalSize,
                        overlaySymbolName: Strings.changeThemeButtonImageSystemName
                    )
                )
            }
        )
    }

    var clearCachesListItem: ListRowView.Configuration {
        .init(
            .button { viewModel.send(.clearCachesButtonTapped) },
            innerText: viewModel.strings.value(for: .clearCachesButtonText),
            imageView: {
                SquareIconView(
                    .init(
                        backgroundColor: Colors.clearCachesButtonImageBackground,
                        overlayFramePercentOfTotalSize: Floats.clearCachesButtonOverlayFramePercentOfTotalSize,
                        overlaySymbolName: Strings.clearCachesButtonImageSystemName,
                        overlaySymbolWeight: .bold
                    )
                )
            }
        )
    }

    var deleteAccountListItem: ListRowView.Configuration {
        .init(
            .button { viewModel.send(.deleteAccountButtonTapped) },
            innerText: viewModel.strings.value(for: .deleteAccountButtonText),
            imageView: {
                SquareIconView(
                    .init(
                        backgroundColor: Colors.deleteAccountButtonImageBackground,
                        overlaySymbolName: Strings.deleteAccountButtonImageSystemName
                    )
                )
            }
        )
    }

    var inviteFriendsListItem: ListRowView.Configuration {
        .init(
            .button { viewModel.send(.inviteFriendsButtonTapped) },
            innerText: viewModel.strings.value(for: .inviteFriendsButtonText),
            imageView: {
                SquareIconView(
                    .init(
                        backgroundColor: Colors.inviteFriendsButtonImageBackground,
                        overlaySymbolName: Strings.inviteFriendsButtonImageSystemName
                    )
                )
            }
        )
    }

    var leaveReviewListItem: ListRowView.Configuration {
        .init(
            .button { viewModel.send(.leaveReviewButtonTapped) },
            innerText: viewModel.strings.value(for: .leaveReviewButtonText),
            imageView: {
                SquareIconView(
                    .init(
                        backgroundColor: Colors.leaveReviewButtonImageBackground,
                        overlaySymbolName: Strings.leaveReviewButtonImageSystemName
                    )
                )
            }
        )
    }

    var penPalsListItem: ListRowView.Configuration {
        .init(
            .switch(isToggled: isPenPalsParticipantBinding),
            headerText: Strings.penPalsListItemHeaderText,
            innerText: viewModel.strings.value(for: .penPalsListRowText), // TODO: Replace with genuine description.
            footerText: "Lorem ipsum dolor sit amet. Consectetur adipiscing elit, sed do eiusmod tempor. Incididunt ut labore et dolore magna aliqua.",
            imageView: {
                SquareIconView.image(.penPalsIcon()).swiftUIImage
            }
        )
    }

    var sendFeedbackListItem: ListRowView.Configuration {
        .init(
            .button { viewModel.send(.sendFeedbackButtonTapped) },
            innerText: Localized(.sendFeedback).wrappedValue,
            imageView: {
                SquareIconView(
                    .init(
                        backgroundColor: Colors.sendFeedbackButtonImageBackground,
                        overlaySymbolName: Strings.sendFeedbackButtonImageSystemName,
                        overlaySymbolWeight: .semibold
                    )
                )
            }
        )
    }

    var signOutListItem: ListRowView.Configuration {
        .init(
            .button { viewModel.send(.signOutButtonTapped) },
            innerText: viewModel.strings.value(for: .signOutButtonText),
            imageView: {
                SquareIconView(
                    .init(
                        backgroundColor: Colors.signOutButtonImageBackground,
                        overlaySymbolName: Strings.signOutButtonImageSystemName
                    )
                )
            }
        )
    }

    // MARK: - Bindings

    private var isPenPalsParticipantBinding: Binding<Bool> {
        viewModel.binding(
            for: \.isPenPalsParticipantSwitchToggled,
            sendAction: { .penPalsParticipantSwitchToggled(on: $0, fromBinding: true) }
        )
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.SettingsPageViewStringKey) -> String {
        (first(where: { $0.key == .settingsPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
