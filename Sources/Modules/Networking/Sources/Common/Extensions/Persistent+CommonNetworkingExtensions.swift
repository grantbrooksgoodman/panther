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
    convenience init(_ sessionStoreKey: PersistentStorageKey.SessionStoreStorageKey) {
        self.init(.sessionStore(sessionStoreKey))
    }
}
