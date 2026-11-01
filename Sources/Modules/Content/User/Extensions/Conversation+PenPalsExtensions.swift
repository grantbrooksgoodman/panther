//
//  Conversation+PenPalsExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 31/10/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension Conversation {
    /// Returns the name under which the given user appears to the
    /// current user in this conversation.
    ///
    /// Resolves to the user's ``User/displayName`` if their identity
    /// is visible to the current user; otherwise, their obfuscated
    /// ``User/penPalsName``. Use this method to display a user
    /// within a conversation; ``User/displayName`` applies the same
    /// rule to any user, whether or not they participate in a given
    /// conversation.
    ///
    /// - Parameter user: The user to query.
    ///
    /// - Returns: The user's display name if their identity is
    ///   visible to the current user; otherwise, their obfuscated
    ///   PenPals name.
    func displayName(for user: User) -> String {
        guard isIdentityVisibleToCurrentUser(user) else {
            return user.penPalsName
        }

        return user.displayName
    }

    /// Returns a Boolean value that indicates whether the given
    /// user's identity is visible to the current user in this
    /// conversation.
    ///
    /// In a PenPals conversation, a participant's identity is
    /// visible to the current user only if the participant shares
    /// their data with the current user in any PenPals conversation
    /// or is known to them. Always `true` when the conversation is
    /// not a PenPals conversation or the given user is not a
    /// participant.
    ///
    /// - Parameter user: The user to query.
    ///
    /// - Returns: `true` if the user's identity is visible to the
    ///   current user; otherwise, `false`.
    ///
    /// - SeeAlso: ``PenPalsService/isKnownToCurrentUser(_:)``
    func isIdentityVisibleToCurrentUser(_ user: User) -> Bool {
        @Dependency(\.commonServices.penPals) var penPalsService: PenPalsService
        guard metadata.isPenPalsConversation,
              participants.map(\.userID).contains(user.id) else { return true }
        return userSharesPenPalsDataWithCurrentUser(user) ||
            penPalsService.sharesPenPalsDataWithCurrentUser(user) ||
            penPalsService.isKnownToCurrentUser(user.id)
    }
}
