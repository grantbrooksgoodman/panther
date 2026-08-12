//
//  Persistent+CommonNetworkingExtensions.swift
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
    /// Creates a persistent value bound to the given session store storage key.
    ///
    /// - Parameter sessionStoreKey: The key that identifies the stored value.
    convenience init(_ sessionStoreKey: PersistentStorageKey.SessionStoreStorageKey) {
        self.init(.sessionStore(sessionStoreKey))
    }
}
