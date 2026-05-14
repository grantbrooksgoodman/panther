//
//  PersistentStorageKey+SessionExtensions.swift
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
    enum UserSessionServiceStorageKey: String {
        case currentUserID
        case offlineCurrentUser
    }
}
