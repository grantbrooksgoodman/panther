//
//  User.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct User: Codable, Equatable {
    // MARK: - Properties

    // Array
    public let conversations: [Conversation]?
    public let pushTokens: [String]?

    // String
    public let id: String
    public let languageCode: String

    // Models
    public let phoneNumber: PhoneNumber

    // MARK: - Init

    public init(
        _ id: String,
        conversations: [Conversation]?,
        languageCode: String,
        phoneNumber: PhoneNumber,
        pushTokens: [String]?
    ) {
        self.id = id
        self.conversations = conversations
        self.languageCode = languageCode
        self.phoneNumber = phoneNumber
        self.pushTokens = pushTokens
    }
}
