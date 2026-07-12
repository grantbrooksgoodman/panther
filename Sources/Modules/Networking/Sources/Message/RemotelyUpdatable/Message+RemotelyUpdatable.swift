//
//  Message+RemotelyUpdatable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

extension Message: RemotelyUpdatable {
    // MARK: - Properties

    var identifier: String {
        id
    }

    // MARK: - Did Write

    func didWrite(
        _ updated: Message,
        forKey key: SerializableKey
    ) async throws(Exception) -> Message {
        @Dependency(\.clientSession.store) var sessionStore: SessionStore
        // Single source of upsert for single-field update calls.
        sessionStore.upsertMessages([updated])
        return updated
    }
}
