//
//  ReactionMetadata.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public struct ReactionMetadata {
    // MARK: - Properties

    public let messageID: String
    public let reactions: [Reaction]

    // MARK: - Init

    public init(
        messageID: String,
        reactions: [Reaction]
    ) {
        self.messageID = messageID
        self.reactions = reactions
    }
}
