//
//  StoredItemKeys.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// Use this extension to define keys for ``RuntimeStorage``.
///
/// Each key identifies a value stored in the in-memory key-value
/// store. Define keys as static properties, then use
/// ``RuntimeStorage/store(_:as:)`` and
/// ``RuntimeStorage/retrieve(_:)`` to access the corresponding
/// values:
///
/// ```swift
/// extension StoredItemKey {
///     static let currentUser: StoredItemKey = .init("currentUser")
/// }
///
/// RuntimeStorage.store(user, as: .currentUser)
/// ```
///
/// - Note: ``RuntimeStorage`` values persist only for the lifetime
///   of the current launch. They are not written to disk.
extension StoredItemKey {
    static let updatedLastSignInDate: StoredItemKey = .init("updatedLastSignInDate")
}

/// Use this extension to add convenience accessors for stored runtime
/// values.
///
/// Each property retrieves and casts the value for a specific
/// ``StoredItemKey``, providing type-safe access without manual
/// casting at the call site:
///
/// ```swift
/// extension RuntimeStorage {
///     static var currentUser: User? { retrieve(.currentUser) as? User }
/// }
/// ```
extension RuntimeStorage {
    static var updatedLastSignInDate: Bool {
        retrieve(.updatedLastSignInDate) as? Bool ?? false
    }
}
