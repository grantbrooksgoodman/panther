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

    public static let empty: UserDataSnapshot = .init(
        .init(timeIntervalSince1970: 0),
        data: .init(),
        expiryThreshold: .zero
    )

    public let data: [String: Any]
    public let date: Date
    public let expiryThreshold: Duration

    // MARK: - Computed Properties

    public var isExpired: Bool {
        Double(abs(date.seconds(from: Date.now) * 1000)) > expiryThreshold.milliseconds
    }

    // MARK: - Init

    public init(
        _ date: Date = .now,
        data: [String: Any],
        expiryThreshold: Duration
    ) {
        self.date = date
        self.data = data
        self.expiryThreshold = expiryThreshold
    }
}
