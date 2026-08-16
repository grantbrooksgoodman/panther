//
//  Persistent+EntitySessionExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension Persistent {
    /// Creates a persistent value bound to the given user session service storage key.
    ///
    /// - Parameter userSessionServiceKey: The key that identifies the stored value.
    convenience init(
        _ userSessionServiceKey: PersistentStorageKey.UserSessionServiceStorageKey
    ) {
        self.init(.userSessionService(userSessionServiceKey))
    }
}
