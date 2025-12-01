//
//  ChatInfoPageViewService+PenPals.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 21/07/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AlertKit
import AppSubsystem

extension ChatInfoPageViewService {
    // MARK: - Present PenPals Sharing Data Confirmation Action Sheet

    /// `.penPalParticipantViewTapped`
    /// `.penPalsSharingDataSwitchToggledOn`
    /// - Returns: `true` if the user selected the confirmation option.
    func presentPenPalsSharingDataConfirmationActionSheet(_ userID: String, displayName: String) async -> ConversationMetadata? {
        await withCheckedContinuation { continuation in
            presentPenPalsSharingDataConfirmationActionSheet(userID, displayName: displayName) { userID in
                continuation.resume(returning: userID)
            }
        }
    }

    private func presentPenPalsSharingDataConfirmationActionSheet(
        _ userID: String,
        displayName: String,
        completion: @escaping (ConversationMetadata?) -> Void
    ) {
        Task {
            let confirmAction: AKAction = .init("Share Phone Number") {
                @Dependency(\.clientSession.conversation.fullConversation) var conversation: Conversation?
                guard let conversation,
                      let currentUserID = User.currentUserID,
                      let currentUserPenPalsSharingData = conversation.currentUserPenPalsSharingData else {
                    return completion(nil)
                }

                let newCurrentUserPenPalsSharingData: PenPalsSharingData = .init(
                    userID: currentUserID,
                    sharesDataWithUserIDs: ((currentUserPenPalsSharingData.sharesDataWithUserIDs ?? []) + [userID]).unique
                )

                var newPenPalsSharingData = conversation.metadata.penPalsSharingData.filter { $0.userID != currentUserID }
                newPenPalsSharingData.append(newCurrentUserPenPalsSharingData)

                let newMetadata: ConversationMetadata = newPenPalsSharingData.allShareWithEachOther ? conversation.metadata.copyWith(
                    isPenPalsConversation: false,
                    penPalsSharingData: PenPalsSharingData.empty(userIDs: conversation.participants.map(\.userID))
                ) : conversation.metadata.copyWith(
                    penPalsSharingData: newPenPalsSharingData
                )

                completion(newMetadata)
            }

            let cancelAction: AKAction = .init(
                Localized(.cancel).wrappedValue,
                style: .cancel
            ) {
                completion(nil)
            }

            Toast.hide()
            await AKActionSheet(
                title: "Share Phone Number with ⌘\(displayName)⌘?", // swiftlint:disable:next line_length
                message: "Both \(RuntimeStorage.languageCode == "en" ? "PenPals" : "parties") sharing their respective phone numbers unlocks the ability to add each other as contacts.\nThis action cannot be undone.",
                actions: [cancelAction, confirmAction]
            ).present(translating: [.actions([confirmAction]), .message, .title])
        }
    }

    // MARK: - Show PenPals Sharing Status Toast

    /// `.penPalParticipantViewTapped`
    func showPenPalsSharingStatusToast(_ userID: String, displayName: String) async {
        Toast.show(
            .init(
                .banner(style: .info, appearanceEdge: .bottom),
                title: displayName,
                message: "You have already shared your phone number with this user.",
                perpetuation: .ephemeral(.seconds(5))
            ),
            translating: [.message]
        )
    }
}
