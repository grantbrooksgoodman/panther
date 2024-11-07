//
//  UserNumberHashSnapshot.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct UserNumberHashSnapshot {
    // MARK: - Properties

    public static let empty: UserNumberHashSnapshot = .init(
        date: .init(timeIntervalSince1970: 0),
        hashes: .init(),
        expiryThreshold: .zero
    )

    public let date: Date
    public let expiryThreshold: Duration
    public let hashes: [String: [String]]

    // MARK: - Computed Properties

    public var isExpired: Bool {
        Double(abs(date.seconds(from: Date()) * 1000)) > expiryThreshold.milliseconds
    }

    // MARK: - Init

    public init(
        date: Date,
        hashes: [String: [String]],
        expiryThreshold: Duration
    ) {
        self.date = date
        self.hashes = hashes
        self.expiryThreshold = expiryThreshold
    }
}
