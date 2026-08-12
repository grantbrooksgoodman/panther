//
//  Participant.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A member of a conversation.
struct Participant: Codable, Equatable {
    // MARK: - Properties

    /// A Boolean value that indicates whether the participant has deleted the conversation.
    let hasDeletedConversation: Bool

    /// A Boolean value that indicates whether the participant is currently typing.
    let isTyping: Bool

    /// The identifier of the participant's user.
    let userID: String

    // MARK: - Init

    /// Creates a participant with the given properties.
    ///
    /// - Parameters:
    ///   - userID: The identifier of the participant's user.
    ///   - hasDeletedConversation: A Boolean value that indicates whether the participant has
    ///     deleted the conversation.
    ///   - isTyping: A Boolean value that indicates whether the participant is currently typing.
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
