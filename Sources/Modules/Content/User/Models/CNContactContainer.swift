//
//  CNContactContainer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 22/03/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
@preconcurrency import Contacts
import Foundation

/// A Contacts framework contact paired with whether it is unknown.
struct CNContactContainer: Equatable {
    // MARK: - Properties

    /// The contact.
    let cnContact: CNMutableContact

    /// A Boolean value that indicates whether the contact is not saved in the user's contact
    /// list.
    let isUnknown: Bool

    // MARK: - Init

    /// Creates a container for the given contact.
    ///
    /// - Parameters:
    ///   - cnContact: The contact.
    ///   - isUnknown: A Boolean value that indicates whether the contact is not saved in the
    ///     user's contact list.
    init(
        _ cnContact: CNMutableContact,
        isUnknown: Bool
    ) {
        self.cnContact = cnContact
        self.isUnknown = isUnknown
    }

    /// Creates a container for the given contact, or returns `nil` if the contact is `nil`.
    ///
    /// - Parameters:
    ///   - cnContact: The contact.
    ///   - isUnknown: A Boolean value that indicates whether the contact is not saved in the
    ///     user's contact list. The default is `false`.
    init?(
        _ cnContact: CNMutableContact?,
        isUnknown: Bool = false
    ) {
        guard let cnContact else { return nil }
        self.init(cnContact, isUnknown: isUnknown)
    }
}
