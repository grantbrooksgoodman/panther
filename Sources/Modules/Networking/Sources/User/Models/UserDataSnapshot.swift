//
//  UserDataSnapshot.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A time-stamped snapshot of a user's serialized data, used for short-lived caching.
struct UserDataSnapshot: @unchecked Sendable {
    // MARK: - Properties

    /// An empty, already-expired snapshot.
    static let empty: UserDataSnapshot = .init(
        .init(timeIntervalSince1970: 0),
        data: .init(),
        expiryThreshold: .zero
    )

    /// The user's serialized data.
    let data: [String: Any]

    /// The date the snapshot was captured.
    let date: Date

    /// The duration after which the snapshot is considered expired.
    let expiryThreshold: Duration

    // MARK: - Computed Properties

    /// A Boolean value that indicates whether the snapshot has expired.
    var isExpired: Bool {
        Double(abs(date.seconds(from: Date.now) * 1000)) > expiryThreshold.milliseconds
    }

    // MARK: - Init

    /// Creates a snapshot with the given data and expiry threshold.
    ///
    /// - Parameters:
    ///   - date: The date the snapshot was captured.
    ///   - data: The user's serialized data.
    ///   - expiryThreshold: The duration after which the snapshot is considered expired.
    init(
        _ date: Date = .now,
        data: [String: Any],
        expiryThreshold: Duration
    ) {
        self.date = date
        self.data = data
        self.expiryThreshold = expiryThreshold
    }
}
