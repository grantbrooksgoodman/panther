//
//  SynchronizationRecord.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

struct SynchronizationRecord: Hashable {
    // MARK: - Properties

    let attempt: Int
    let conversationIDKey: String
    let date: Date

    /// Cooldown durations for exponential backoff (seconds).
    private static let cooldowns: [TimeInterval] = [3, 15, 60]

    // MARK: - Computed Properties

    var isExpired: Bool {
        TimeInterval(abs(date.seconds(from: .now))) >= Self.cooldowns[
            min(attempt - 1, Self.cooldowns.count - 1)
        ]
    }

    // MARK: - Init

    init(
        conversationIDKey: String,
        attempt: Int = 1,
        date: Date = .now
    ) {
        self.attempt = attempt
        self.conversationIDKey = conversationIDKey
        self.date = date
    }

    // MARK: - Equatable Conformance

    static func == (
        left: Self,
        right: Self
    ) -> Bool {
        left.conversationIDKey == right.conversationIDKey
    }

    // MARK: - Hashable Conformance

    func hash(into hasher: inout Hasher) {
        hasher.combine(conversationIDKey)
    }
}
