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

struct PenPalsSharingData: Codable, Equatable {
    // MARK: - Properties

    let sharesDataWithUserIDs: [String]?
    let userID: String

    // MARK: - Init

    init(userID: String, sharesDataWithUserIDs: [String]? = nil) {
        assert(
            sharesDataWithUserIDs == nil ? true : !sharesDataWithUserIDs!.isBangQualifiedEmpty,
            "Instantiated PenPalsSharingData with empty sharesDataWithUserIDs array"
        )

        self.userID = userID
        self.sharesDataWithUserIDs = sharesDataWithUserIDs
    }

    // MARK: - Default Values

    static func empty(userIDs: [String]) -> [PenPalsSharingData] {
        userIDs.reduce(into: [PenPalsSharingData]()) { partialResult, userID in
            partialResult.append(.init(userID: userID))
        }
    }

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
