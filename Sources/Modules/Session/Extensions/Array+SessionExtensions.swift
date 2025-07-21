//
//  Array+SessionExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension Array where Element == ReactionMetadata {
    func filteringCurrentUserReactions(to messageID: String) -> [ReactionMetadata] {
        func satisfiesConstraints(_ metadata: ReactionMetadata) -> Bool {
            guard metadata.messageID == messageID,
                  metadata.reactions.map(\.userID).contains(User.currentUserID) else { return false }
            return true
        }

        var array = self // NIT: Shouldn't _technically_ need a for loop here, as only one ReactionMetadata can exist for a given message ID.
        for (index, metadata) in array.enumerated() where satisfiesConstraints(metadata) {
            let newMetadata = ReactionMetadata(
                messageID: metadata.messageID,
                reactions: metadata.reactions.filter { $0.userID != User.currentUserID }
            )

            array.remove(at: index)
            guard !newMetadata.reactions.isEmpty else { continue }
            array.insert(newMetadata, at: index)
        }

        return array.isEmpty ? [.empty] : array
    }
}
