//
//  CNContactContainer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 22/03/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Contacts
import Foundation

public struct CNContactContainer: Equatable {
    // MARK: - Properties

    public let cnContact: CNMutableContact
    public let isUnknown: Bool

    // MARK: - Init

    public init(_ cnContact: CNMutableContact, isUnknown: Bool) {
        self.cnContact = cnContact
        self.isUnknown = isUnknown
    }

    public init?(_ cnContact: CNMutableContact?, isUnknown: Bool = false) {
        guard let cnContact else { return nil }
        self.init(cnContact, isUnknown: isUnknown)
    }
}
