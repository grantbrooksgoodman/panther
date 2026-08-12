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

extension PenPalsSharingData {
    /// A Boolean value that indicates whether this record's user shares their PenPals data with
    /// the current user, or `nil` when the record belongs to the current user.
    var sharesDataWithCurrentUser: Bool? {
        guard let currentUserID = User.currentUserID,
              userID != currentUserID else { return nil }
        return (sharesDataWithUserIDs ?? []).contains(currentUserID)
    }
}
