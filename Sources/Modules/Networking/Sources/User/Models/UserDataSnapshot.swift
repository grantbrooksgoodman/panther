//
//  UserDataSnapshot.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

struct UserDataSnapshot {
    // MARK: - Properties

    static let empty: UserDataSnapshot = .init(
        .init(timeIntervalSince1970: 0),
        data: .init(),
        expiryThreshold: .zero
    )

    let data: [String: Any]
    let date: Date
    let expiryThreshold: Duration

    // MARK: - Computed Properties

    var isExpired: Bool {
        Double(abs(date.seconds(from: Date.now) * 1000)) > expiryThreshold.milliseconds
    }

    // MARK: - Init

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
