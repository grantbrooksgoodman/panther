//
//  SettingsPageView+GroupedListItems.swift
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

public extension SettingsPageView {
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
                        overlay: .symbol(name: Strings.blockedUsersButtonImageSystemName)
                    )
                )
            }
        )
    }

    var changeThemeListItem: ListRowView.Configuration {
        .init(
            .button { viewModel.send(.changeThemeButtonTapped) },
            innerText: viewModel.strings.value(for: .changeThemeButtonText),
            isEnabled: viewModel.isChangeThemeButtonEnabled,
            imageView: {
                SquareIconView(
                    .init(
                        backgroundColor: Colors.changeThemeButtonImageBackground,
                        overlay: .symbol(
                            name: Strings.changeThemeButtonImageSystemName,
                            framePercentOfTotalSize: Floats.changeThemeButtonOverlayFramePercentOfTotalSize
                        )
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
                        overlay: .symbol(
                            name: Strings.clearCachesButtonImageSystemName,
                            framePercentOfTotalSize: Floats.clearCachesButtonOverlayFramePercentOfTotalSize,
                            weight: .bold
                        )
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
                        overlay: .symbol(name: Strings.deleteAccountButtonImageSystemName)
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
                        overlay: .symbol(name: Strings.inviteFriendsButtonImageSystemName)
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
                        overlay: .symbol(name: Strings.leaveReviewButtonImageSystemName)
                    )
                )
            }
        )
    }

    var messageRecipientConsentListItem: ListRowView.Configuration {
        .init(
            .switch(isToggled: isMessageRecipientConsentSwitchToggledBinding),
            innerText: viewModel.strings.value(for: .recipientConsentListRowInnerText),
            footerText: viewModel.strings.value(for: .recipientConsentListRowFooterText),
            imageView: {
                SquareIconView(
                    .init(
                        backgroundColor: Colors.messageRecipientConsentButtonImageBackground,
                        overlay: .symbol(name: Strings.messageRecipientConsentButtonImageSystemName)
                    )
                )
            }
        )
    }

    var penPalsListItem: ListRowView.Configuration {
        .init(
            .switch(isToggled: isPenPalsParticipantSwitchToggledBinding),
            innerText: viewModel.strings.value(for: .penPalsListRowInnerText),
            footerText: viewModel.strings.value(for: .penPalsListRowFooterText),
            imageView: {
                SquareIconView(.penPalsIcon())
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
                        overlay: .symbol(
                            name: Strings.sendFeedbackButtonImageSystemName,
                            weight: .semibold
                        )
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
                        overlay: .symbol(name: Strings.signOutButtonImageSystemName)
                    )
                )
            }
        )
    }

    // MARK: - Bindings

    // swiftlint:disable:next identifier_name
    private var isMessageRecipientConsentSwitchToggledBinding: Binding<Bool> {
        viewModel.binding(
            for: \.isMessageRecipientConsentSwitchToggled,
            sendAction: { .messageRecipientConsentSwitchToggled(on: $0) }
        )
    }

    private var isPenPalsParticipantSwitchToggledBinding: Binding<Bool> {
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
