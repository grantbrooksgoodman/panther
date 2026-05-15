//
//  User+RemotelyUpdatable.swift
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

extension User: RemotelyUpdatable {
    // MARK: - Properties

    var identifier: String {
        id
    }

    // MARK: - Will Write

    func willWrite(
        _ value: Any,
        forKey key: SerializableKey,
        updating updated: User
    ) async throws(Exception) -> WriteAction<User> {
        @Dependency(\.timestampDateFormatter) var timestampDateFormatter: DateFormatter
        guard let date = value as? Date else { return .proceed }
        return .encoded(timestampDateFormatter.string(from: date))
    }
}
