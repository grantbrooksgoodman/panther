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

    /// The message's identifier.
    var identifier: String {
        id
    }

    // MARK: - Did Write

    /// Applies a completed single-field remote update, upserting the updated message into the
    /// session store.
    ///
    /// - Parameters:
    ///   - updated: The updated message.
    ///   - key: The serializable key of the field that was updated.
    ///
    /// - Returns: The updated message.
    ///
    /// - Throws: An `Exception` if applying the update fails.
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
