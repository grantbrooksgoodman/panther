//
//  ContactPair.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct ContactPair: Codable, Equatable {
    // MARK: - Properties

    public let contact: Contact
    public let numberPairs: [NumberPair]?

    // MARK: - Init

    public init(contact: Contact, numberPairs: [NumberPair]?) {
        self.contact = contact
        self.numberPairs = numberPairs
    }
}
