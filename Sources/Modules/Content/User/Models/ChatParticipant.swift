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
    // MARK: - Properties

    public let cnContactContainer: CNContactContainer?
    public let contactPair: ContactPair?
    public let displayName: String
    public let isUserInteractionEnabled: Bool

    // MARK: - Computed Properties

    public var firstUser: User? { contactPair?.users.first }
    public var thumbnailImage: UIImage? { contactPair?.contact.image }

    // MARK: - Init

    public init(
        displayName: String,
        cnContactContainer: CNContactContainer?,
        contactPair: ContactPair?,
        isUserInteractionEnabled: Bool = true
    ) {
        self.displayName = displayName
        self.cnContactContainer = cnContactContainer
        self.contactPair = contactPair
        self.isUserInteractionEnabled = isUserInteractionEnabled
    }
}
