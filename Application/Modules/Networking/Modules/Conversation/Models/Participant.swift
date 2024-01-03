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
    public let userIDKey: String

    // MARK: - Init

    public init(
        userIDKey: String,
        hasDeletedConversation: Bool = false,
        isTyping: Bool = false
    ) {
        self.userIDKey = userIDKey
        self.hasDeletedConversation = hasDeletedConversation
        self.isTyping = isTyping
    }
}
