//
//  NewUserMetadata.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct NewUserMetadata: Codable, Equatable {
    // MARK: - Properties

    public let id: String
    public let languageCode: String
    public let phoneNumber: PhoneNumber
    public let pushTokens: [String]

    // MARK: - Init

    public init(
        id: String,
        languageCode: String,
        phoneNumber: PhoneNumber,
        pushTokens: [String]?
    ) {
        self.id = id
        self.languageCode = languageCode
        self.phoneNumber = phoneNumber
        self.pushTokens = pushTokens ?? .bangQualifiedEmpty
    }
}
