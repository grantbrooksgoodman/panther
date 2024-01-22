//
//  UserDataSnapshot.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct UserDataSnapshot {
    // MARK: - Properties

    public let data: [String: Any]
    public let date: Date
    public let expiryThreshold: Duration

    // MARK: - Computed Properties

    public static var empty: UserDataSnapshot {
        .init(
            date: .init(timeIntervalSince1970: 0),
            data: .init(),
            expiryThreshold: .zero
        )
    }

    public var isExpired: Bool {
        Double(abs(date.seconds(from: Date()) * 1000)) > expiryThreshold.milliseconds
    }

    // MARK: - Init

    public init(
        date: Date,
        data: [String: Any],
        expiryThreshold: Duration
    ) {
        self.date = date
        self.data = data
        self.expiryThreshold = expiryThreshold
    }
}
