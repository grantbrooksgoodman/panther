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
        hasDeletedConversation: Bool = false,
        isTyping: Bool = false
    ) {
        self.userID = userID
        self.hasDeletedConversation = hasDeletedConversation
        self.isTyping = isTyping
    }
}
