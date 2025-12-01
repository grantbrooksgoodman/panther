//
//  ContactPair.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

struct ContactPair: Codable, Hashable {
    // MARK: - Properties

    static let empty: ContactPair = .mock(withName: "")

    let contact: Contact
    let numberPairs: [NumberPair]

    // MARK: - Init

    init(contact: Contact, numberPairs: [NumberPair]) {
        assert(!numberPairs.isEmpty, "Initialized ContactPair with empty NumberPair array")
        self.contact = contact
        self.numberPairs = numberPairs
    }

    // MARK: - Hashable Conformance

    func hash(into hasher: inout Hasher) {
        hasher.combine(contact.id)
        hasher.combine(numberPairs.map(\.phoneNumber.compiledNumberString))
        hasher.combine(numberPairs.map { $0.users.map(\.id) }.reduce([], +))
    }
}
