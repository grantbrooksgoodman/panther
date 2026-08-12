//
//  PersistentStorageKey+CommonNetworkingExtensions.swift
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
    /// The persistent storage keys scoped to the session store.
    enum SessionStoreStorageKey: String {
        case conversationArchive
        case messageArchive
        case messageOutbox
        case userArchive
    }
}
