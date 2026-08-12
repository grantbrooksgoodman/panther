//
//  ChatParticipantView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 21/07/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

/// A row describing a participant in a conversation.
///
/// Use ``ChatParticipantView`` to display a participant's avatar, display name, and user info
/// badge, with an optional PenPals sharing status icon and an optional swipe-to-delete
/// action.
struct ChatParticipantView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatParticipantView
    private typealias Floats = AppConstants.CGFloats.ChatParticipantView
    private typealias Strings = AppConstants.Strings.ChatParticipantView

    // MARK: - Properties

    private let participant: ChatParticipant
    private let deleteAction: (() -> Void)?
    private let userInfoBadgeViewAction: (() -> Void)?

    // MARK: - Init

    /// Creates a chat participant row.
    ///
    /// - Parameters:
    ///   - participant: The participant the row describes.
    ///   - deleteAction: The action a trailing swipe performs. Pass `nil` to omit the swipe
    ///     action.
    ///   - userInfoBadgeViewAction: The action performed when the user taps the user info
    ///     badge. Pass `nil` for no action.
    init(
        _ participant: ChatParticipant,
        deleteAction: (() -> Void)?,
        userInfoBadgeViewAction: (() -> Void)?
    ) {
        self.participant = participant
        self.deleteAction = deleteAction
        self.userInfoBadgeViewAction = userInfoBadgeViewAction
    }

    // MARK: - View

    /// The content and behavior of the view.
    var body: some View {
        HStack {
            AvatarImageView(
                participant.thumbnailImage,
                size: .init(
                    width: Floats.avatarImageViewSizeWidth,
                    height: Floats.avatarImageViewSizeHeight
                )
            )
            .padding(.trailing, Floats.avatarImageViewTrailingPadding)

            ThemedView {
                Group {
                    Components.text(
                        participant.displayName,
                        font: .systemSemibold,
                        isInspectable: UIApplication.isFullyV26Compatible
                    )

                    if let firstUser = participant.firstUser {
                        UserInfoBadgeView(
                            firstUser,
                            action: userInfoBadgeViewAction
                        )
                    }
                }
            }

            if let penPalsStatus = participant.penPalsStatus {
                Spacer()

                switch penPalsStatus {
                case .currentUserSharesData:
                    Components.symbol(
                        Strings.penPalsSharingStatusIconCompleteImageSystemName,
                        foregroundColor: Colors.penPalsSharingStatusIconCompleteForeground
                    )

                case .currentUserDoesNotShareData:
                    Components.symbol(
                        Strings.penPalsSharingStatusIconIncompleteImageSystemName,
                        foregroundColor: Colors.penPalsSharingStatusIconIncompleteForeground
                    )
                }
            }
        }
        .ifLet(deleteAction) { body, deleteAction in
            body
                .swipeActions(
                    edge: .trailing,
                    allowsFullSwipe: false
                ) {
                    Button {
                        deleteAction()
                    } label: {
                        Image(systemName: Strings.deleteButtonImageSystemName)
                    }
                    .tint(Colors.deleteButtonTint)
                }
        }
    }
}
