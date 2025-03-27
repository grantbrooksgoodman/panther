//
//  PenPalsSharingData+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 21/03/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

public extension PenPalsSharingData {
    /// - Note: Returns `nil` if accessed on the current user.
    var sharesDataWithCurrentUser: Bool? {
        @Dependency(\.clientSession.user.currentUser?.id) var currentUserID: String?
        @Persistent(.currentUserID) var fallbackCurrentUserID: String?
        guard let resolvedCurrentUserID = currentUserID ?? fallbackCurrentUserID,
              userID != resolvedCurrentUserID else { return nil }
        return (sharesDataWithUserIDs ?? []).contains(resolvedCurrentUserID)
    }
}
