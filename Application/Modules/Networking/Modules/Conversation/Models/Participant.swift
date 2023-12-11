//
//  Participant.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct Participant: Codable, Equatable {
    // MARK: - Properties

    // Bool
    public let hasDeletedConversation: Bool
    public let isTyping: Bool

    // String
    public let userID: String

    // MARK: - Init

    public init(
        userID: String,
        hasDeletedConversation: Bool,
        isTyping: Bool
    ) {
        self.userID = userID
        self.hasDeletedConversation = hasDeletedConversation
        self.isTyping = isTyping
    }

    public init?(_ string: String) {
        let components = string.components(separatedBy: " | ")
        guard components.count == 3,
              components[1] == "true" || components[1] == "false",
              components[2] == "true" || components[2] == "false" else { return nil }

        let userID = components[0]
        let hasDeletedConversation = components[1] == "true" ? true : false
        let isTyping = components[2] == "true" ? true : false

        self.init(
            userID: userID,
            hasDeletedConversation: hasDeletedConversation,
            isTyping: isTyping
        )
    }
}
