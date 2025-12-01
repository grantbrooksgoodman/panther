//
//  Participant.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

struct Participant: Codable, Equatable {
    // MARK: - Properties

    // Bool
    let hasDeletedConversation: Bool
    let isTyping: Bool

    // String
    let userID: String

    // MARK: - Init

    init(
        userID: String,
        hasDeletedConversation: Bool = false,
        isTyping: Bool = false
    ) {
        self.userID = userID
        self.hasDeletedConversation = hasDeletedConversation
        self.isTyping = isTyping
    }
}
