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
    public let numberData: PhoneNumberMetadata
    public let pushTokens: [String]

    // MARK: - Init

    public init(
        id: String,
        languageCode: String,
        numberData: PhoneNumberMetadata,
        pushTokens: [String]?
    ) {
        self.id = id
        self.languageCode = languageCode
        self.numberData = numberData
        self.pushTokens = pushTokens ?? .bangQualifiedEmpty
    }
}
