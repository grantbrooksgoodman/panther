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

public struct ChatParticipant: Equatable {
    // MARK: - Types

    public enum PenPalsStatus {
        case currentUserSharesData
        case currentUserDoesNotShareData
    }

    // MARK: - Properties

    public let cnContactContainer: CNContactContainer?
    public let contactPair: ContactPair
    public let displayName: String
    public let penPalsStatus: PenPalsStatus?

    // MARK: - Computed Properties

    public var firstUser: User? { contactPair.users.first }
    public var thumbnailImage: UIImage? {
        penPalsStatus != nil ? SquareIconView.image(
            .penPalsIcon(
                backgroundColor: .init(uiColor: firstUser?.penPalsIconColor ?? .purple)
            )
        ) : contactPair.contact.image
    }

    // MARK: - Init

    public init(
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
