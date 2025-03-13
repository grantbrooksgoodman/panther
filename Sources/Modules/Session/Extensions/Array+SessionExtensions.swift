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
    func filteringCurrentUserReactions(to message: Message) -> [ReactionMetadata] {
        @Persistent(.currentUserID) var currentUserID: String?
        func satisfiesConstraints(_ metadata: ReactionMetadata) -> Bool {
            guard metadata.messageID == message.id,
                  metadata.reactions.map(\.userID).contains(currentUserID) else { return false }
            return true
        }

        var array = self // NIT: Shouldn't _technically_ need a for loop here, as only one ReactionMetadata can exist for a given message ID.
        for (index, metadata) in array.enumerated() where satisfiesConstraints(metadata) {
            let newMetadata = ReactionMetadata(
                messageID: metadata.messageID,
                reactions: metadata.reactions.filter { $0.userID != currentUserID }
            )

            array.remove(at: index)
            guard !newMetadata.reactions.isEmpty else { continue }
            array.insert(newMetadata, at: index)
        }

        return array.isEmpty ? [.empty] : array
    }
}
