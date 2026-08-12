//
//  ContactPair.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A device contact paired with the phone numbers that map it to registered users.
///
/// A contact pair associates a ``Contact`` with one or more ``NumberPair`` values – the
/// contact's phone numbers together with the registered users they resolve to. Use contact
/// pairs to determine which of the user's contacts can be messaged.
struct ContactPair: Codable, Hashable {
    // MARK: - Properties

    /// A placeholder contact pair with an empty name.
    static let empty: ContactPair = .mock(withName: "")

    /// The device contact.
    let contact: Contact

    /// The contact's phone numbers, each paired with the registered users it resolves to.
    let numberPairs: [NumberPair]

    // MARK: - Init

    /// Creates a contact pair with the given contact and number pairs.
    ///
    /// - Parameters:
    ///   - contact: The device contact.
    ///   - numberPairs: The contact's phone numbers, each paired with the registered users it
    ///     resolves to. Must not be empty.
    init(
        contact: Contact,
        numberPairs: [NumberPair]
    ) {
        assert(
            !numberPairs.isEmpty,
            "Initialized ContactPair with empty NumberPair array"
        )

        self.contact = contact
        self.numberPairs = numberPairs
    }

    // MARK: - Hashable Conformance

    /// Hashes the contact's identifier, the pairs' compiled number strings, and their user IDs.
    func hash(into hasher: inout Hasher) {
        hasher.combine(contact.id)
        hasher.combine(numberPairs.map(\.phoneNumber.compiledNumberString))
        hasher.combine(numberPairs.flatMap(\.userIDs))
    }
}
