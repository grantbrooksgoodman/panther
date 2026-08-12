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

    /// Asks the user to confirm sharing their phone number with the given PenPal.
    ///
    /// The action sheet explains that mutual sharing unlocks adding each other as contacts,
    /// and that the action cannot be undone.
    ///
    /// - Parameters:
    ///   - userID: The ID of the user to share with.
    ///   - displayName: The name the action sheet displays.
    ///
    /// - Returns: The given user ID if the user confirmed; otherwise, `nil`.
    func presentPenPalsSharingDataConfirmationActionSheet(
        _ userID: String,
        displayName: String
    ) async -> String? {
        await withCheckedContinuation { continuation in
            presentPenPalsSharingDataConfirmationActionSheet(
                userID,
                displayName: displayName
            ) { userID in
                continuation.resume(returning: userID)
            }
        }
    }

    private func presentPenPalsSharingDataConfirmationActionSheet(
        _ userID: String,
        displayName: String,
        completion: @escaping @Sendable (String?) -> Void
    ) {
        Task {
            let confirmAction: AKAction = .init("Share Phone Number") {
                completion(userID)
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

    /// Shows a toast explaining that the current user has already shared their phone number
    /// with the given user.
    ///
    /// - Parameters:
    ///   - userID: The ID of the user the toast concerns.
    ///   - displayName: The name the toast displays.
    func showPenPalsSharingStatusToast(
        _ userID: String,
        displayName: String
    ) async {
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
