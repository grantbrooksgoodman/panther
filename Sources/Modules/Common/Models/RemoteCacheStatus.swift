//
//  RemoteCacheStatus.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// The validity of a user's remote cache.
///
/// The remote cache status is stored per user in the remote database. When the status is
/// ``invalid``, the app resets its local data during bundle initialization and re-fetches it
/// from the server.
enum RemoteCacheStatus {
    /// The cache has been invalidated and must be rebuilt.
    case invalid

    /// The cache is valid.
    case valid
}
