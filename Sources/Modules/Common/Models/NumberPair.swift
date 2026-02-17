//
//  NumberPair.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

// NIT: Need to either use phone number strings or conform PhoneNumber to not auto-resolve a calling code.
struct NumberPair: Codable, Hashable {
    // MARK: - Properties

    let phoneNumber: PhoneNumber
    let users: [User]

    // MARK: - Init

    init(phoneNumber: PhoneNumber, users: [User]) {
        assert(!users.isEmpty, "Initialized NumberPair with empty User array")
        self.phoneNumber = phoneNumber
        self.users = users
    }

    // MARK: - Hashable Conformance

    func hash(into hasher: inout Hasher) {
        hasher.combine(phoneNumber)
        hasher.combine(users)
    }
}
