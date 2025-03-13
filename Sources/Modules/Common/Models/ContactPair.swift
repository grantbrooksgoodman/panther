//
//  ContactPair.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct ContactPair: Codable, Hashable {
    // MARK: - Properties

    public static let empty: ContactPair = .mock(withName: "")

    public let contact: Contact
    public let numberPairs: [NumberPair]

    // MARK: - Init

    public init(contact: Contact, numberPairs: [NumberPair]) {
        assert(!numberPairs.isEmpty, "Initialized ContactPair with empty NumberPair array")
        self.contact = contact
        self.numberPairs = numberPairs
    }

    // MARK: - Hashable Conformance

    public func hash(into hasher: inout Hasher) {
        hasher.combine(contact.id)
        hasher.combine(numberPairs.map(\.phoneNumber.compiledNumberString))
        hasher.combine(numberPairs.map { $0.users.map(\.id) }.reduce([], +))
    }
}
