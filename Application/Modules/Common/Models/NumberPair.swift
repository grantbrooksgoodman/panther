//
//  NumberPair.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct NumberPair: Codable, Equatable {
    // MARK: - Properties

    public let phoneNumber: PhoneNumber
    public let users: [User]

    // MARK: - Init

    public init(phoneNumber: PhoneNumber, users: [User]) {
        self.phoneNumber = phoneNumber
        self.users = users
    }
}
