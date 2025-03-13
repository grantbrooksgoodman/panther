//
//  TranslationDataSnapshot.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public struct TranslationDataSnapshot: Equatable {
    // MARK: - Properties

    public static let empty: TranslationDataSnapshot = .init(
        .init(timeIntervalSince1970: 0),
        data: .init(),
        expiryThreshold: .zero
    )

    public let data: [String: [String: Any]]
    public let date: Date
    public let expiryThreshold: Duration

    // MARK: - Computed Properties

    public var isExpired: Bool {
        Double(abs(date.seconds(from: Date()) * 1000)) > expiryThreshold.milliseconds
    }

    // MARK: - Init

    public init(
        _ date: Date = .now,
        data: [String: [String: Any]],
        expiryThreshold: Duration
    ) {
        self.date = date
        self.data = data
        self.expiryThreshold = expiryThreshold
    }

    // MARK: - Equatable Conformance

    public static func == (left: TranslationDataSnapshot, right: TranslationDataSnapshot) -> Bool {
        let sameDataCount = left.data.count == right.data.count
        let sameDataKeys = left.data.keys == right.data.keys
        let sameDataValueKeys = left.data.values.map(\.keys) == right.data.values.map(\.keys)
        let sameDate = left.date == right.date
        let sameExpiryThreshold = left.expiryThreshold == right.expiryThreshold

        guard sameDataCount,
              sameDataKeys,
              sameDataValueKeys,
              sameDate,
              sameExpiryThreshold else { return false }

        return true
    }
}
