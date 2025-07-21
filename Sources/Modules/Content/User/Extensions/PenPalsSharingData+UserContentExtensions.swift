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
        guard let currentUserID = User.currentUserID,
              userID != currentUserID else { return nil }
        return (sharesDataWithUserIDs ?? []).contains(currentUserID)
    }
}
