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
    public let conversationIDs: [ConversationID]?
    public let pushTokens: [String]?

    // String
    public let id: String
    public let languageCode: String

    // Models
    public let numberData: PhoneNumber

    // MARK: - Init

    public init(
        _ id: String,
        conversationIDs: [ConversationID]?,
        languageCode: String,
        numberData: PhoneNumber,
        pushTokens: [String]?
    ) {
        self.id = id
        self.conversationIDs = conversationIDs
        self.languageCode = languageCode
        self.numberData = numberData
        self.pushTokens = pushTokens
    }

    public init(_ newUserMetadata: NewUserMetadata) {
        self.init(
            newUserMetadata.id,
            conversationIDs: nil,
            languageCode: newUserMetadata.languageCode,
            numberData: newUserMetadata.numberData,
            pushTokens: newUserMetadata.pushTokens.isBangQualifiedEmpty ? nil : newUserMetadata.pushTokens
        )
    }
}
