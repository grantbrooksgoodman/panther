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

struct ChatParticipant: Equatable {
    // MARK: - Types

    enum PenPalsStatus {
        case currentUserSharesData
        case currentUserDoesNotShareData
    }

    // MARK: - Properties

    let cnContactContainer: CNContactContainer?
    let contactPair: ContactPair
    let displayName: String
    let penPalsStatus: PenPalsStatus?

    // MARK: - Computed Properties

    var firstUser: User? { contactPair.users.first }

    @MainActor
    var thumbnailImage: UIImage? {
        penPalsStatus != nil ? SquareIconView.image(
            .penPalsIcon(
                backgroundColor: .init(uiColor: firstUser?.penPalsIconColor ?? .purple)
            )
        ) : contactPair.contact.image
    }

    // MARK: - Init

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
