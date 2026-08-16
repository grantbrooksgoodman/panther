//
//  PersistentStorageKey+EntitySessionExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension PersistentStorageKey {
    /// The persistent storage keys scoped to the user session service.
    enum UserSessionServiceStorageKey: String {
        case currentUserID
    }
}
