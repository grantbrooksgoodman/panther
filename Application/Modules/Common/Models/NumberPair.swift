//
//  NumberPair.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

// TODO: Need to either use phone number strings or conform PhoneNumber to not auto-resolve a calling code.
public struct NumberPair: Codable, Equatable {
    // MARK: - Properties

    public let phoneNumber: PhoneNumber
    public let users: [User]

    // MARK: - Init

    public init(phoneNumber: PhoneNumber, users: [User]) {
        assert(!users.isEmpty, "Initialized NumberPair with empty User array")
        self.phoneNumber = phoneNumber
        self.users = users
    }
}
