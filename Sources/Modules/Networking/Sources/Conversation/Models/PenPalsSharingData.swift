//
//  PenPalsSharingData.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// A record of the participants a conversation participant shares their data with in a PenPals
/// conversation.
///
/// In a PenPals conversation, a participant's identity remains obfuscated to the other
/// participants until they share their data.
struct PenPalsSharingData: Codable, Equatable {
    // MARK: - Properties

    /// The identifiers of the users the participant shares their data with, or `nil` if the
    /// participant shares with no one.
    let sharesDataWithUserIDs: [String]?

    /// The identifier of the participant's user.
    let userID: String

    // MARK: - Init

    /// Creates a sharing record with the given properties.
    ///
    /// - Parameters:
    ///   - userID: The identifier of the participant's user.
    ///   - sharesDataWithUserIDs: The identifiers of the users the participant shares their data
    ///     with, or `nil` if the participant shares with no one.
    ///
    /// - Important: If `sharesDataWithUserIDs` is non-`nil`, it must not be empty.
    init(
        userID: String,
        sharesDataWithUserIDs: [String]? = nil
    ) {
        assert(
            sharesDataWithUserIDs == nil ? true : !sharesDataWithUserIDs!.isBangQualifiedEmpty,
            "Instantiated PenPalsSharingData with empty sharesDataWithUserIDs array"
        )

        self.userID = userID
        self.sharesDataWithUserIDs = sharesDataWithUserIDs
    }

    // MARK: - Default Values

    /// Returns a sharing record for each of the given users, each sharing with no one.
    ///
    /// - Parameter userIDs: The identifiers of the users to create records for.
    ///
    /// - Returns: The sharing records.
    static func empty(userIDs: [String]) -> [PenPalsSharingData] {
        userIDs.reduce(into: [PenPalsSharingData]()) { partialResult, userID in
            partialResult.append(.init(userID: userID))
        }
    }

    /// Returns a sharing record for each of the given users, seeding the current user's record
    /// with the other participants already known to them.
    ///
    /// Every other participant's record shares with no one. If the current user is not among the
    /// given users, this method returns the same result as ``empty(userIDs:)``.
    ///
    /// - Parameter userIDs: The identifiers of the users to create records for.
    ///
    /// - Returns: The sharing records.
    static func prepopulated(userIDs: [String]) -> [PenPalsSharingData] {
        @Dependency(\.commonServices.penPals) var penPalsService: PenPalsService

        let userIDs = userIDs.unique
        guard let currentUserID = User.currentUserID,
              userIDs.contains(currentUserID) else { return empty(userIDs: userIDs) }

        let knownToCurrentUser = userIDs.filter { $0 != currentUserID && penPalsService.isKnownToCurrentUser($0) }
        return userIDs.reduce(into: [PenPalsSharingData]()) { partialResult, userID in
            if userID == currentUserID {
                partialResult.append(.init(
                    userID: userID,
                    sharesDataWithUserIDs: knownToCurrentUser.isEmpty ? nil : knownToCurrentUser
                ))
            } else {
                partialResult.append(.init(userID: userID))
            }
        }
    }
}
