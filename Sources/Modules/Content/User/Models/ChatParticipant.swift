//
//  ChatParticipant.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 21/03/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/// A participant in a conversation, prepared for display.
///
/// Use ``ChatParticipant`` to combine a participant's contact information with their display
/// name and PenPals sharing status.
struct ChatParticipant: Equatable {
    // MARK: - Types

    /// The state of PenPals data sharing between the current user and a participant.
    enum PenPalsStatus {
        /// The current user shares their data with the participant.
        case currentUserSharesData

        /// The current user does not share their data with the participant.
        case currentUserDoesNotShareData
    }

    // MARK: - Properties

    /// The participant's Contacts framework contact, or `nil` if none exists.
    let cnContactContainer: CNContactContainer?

    /// The contact pair describing the participant.
    let contactPair: ContactPair

    /// The name the participant row displays.
    let displayName: String

    /// The participant's PenPals sharing status, or `nil` outside PenPals conversations.
    let penPalsStatus: PenPalsStatus?

    // MARK: - Computed Properties

    /// The first user associated with the participant's contact pair.
    var firstUser: User? {
        contactPair.users.first
    }

    /// The participant's thumbnail image – the PenPals icon in PenPals conversations;
    /// otherwise, the contact's image.
    @MainActor
    var thumbnailImage: UIImage? {
        penPalsStatus != nil ? SquareIconView.image(
            .penPalsIcon(
                backgroundColor: .init(uiColor: firstUser?.penPalsIconColor ?? .purple)
            )
        ) : contactPair.contact.image
    }

    // MARK: - Init

    /// Creates a chat participant.
    ///
    /// - Parameters:
    ///   - displayName: The name the participant row displays.
    ///   - cnContactContainer: The participant's Contacts framework contact, or `nil` if none
    ///     exists.
    ///   - contactPair: The contact pair describing the participant.
    ///   - penPalsStatus: The participant's PenPals sharing status, or `nil` outside PenPals
    ///     conversations.
    init(
        displayName: String,
        cnContactContainer: CNContactContainer?,
        contactPair: ContactPair,
        penPalsStatus: PenPalsStatus?
    ) {
        self.displayName = displayName
        self.cnContactContainer = cnContactContainer
        self.contactPair = contactPair
        self.penPalsStatus = penPalsStatus
    }
}
