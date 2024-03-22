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

    // MARK: - Computed Properties

    public var thumbnailImage: UIImage? {
        guard let imageData = contactPair?.contact.imageData else { return nil }
        return .init(data: imageData)
    }

    // MARK: - Init

    public init(
        displayName: String,
        cnContactContainer: CNContactContainer?,
        contactPair: ContactPair?
    ) {
        self.displayName = displayName
        self.cnContactContainer = cnContactContainer
        self.contactPair = contactPair
    }
}
