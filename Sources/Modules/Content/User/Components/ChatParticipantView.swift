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

struct ChatParticipantView: View {
    // MARK: - Constants Accesors

    private typealias Colors = AppConstants.Colors.ChatParticipantView
    private typealias Floats = AppConstants.CGFloats.ChatParticipantView
    private typealias Strings = AppConstants.Strings.ChatParticipantView

    // MARK: - Properties

    private let participant: ChatParticipant
    private let deleteAction: (() -> Void)?
    private let userInfoBadgeViewAction: (() -> Void)?

    // MARK: - Init

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
                        isInspectable: UIApplication.v26FeaturesEnabled
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
