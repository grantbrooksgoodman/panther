//
//  SynchronizationRecord.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A record of a failed conversation synchronization attempt, used to apply a backoff cooldown
/// before retrying.
struct SynchronizationRecord: Hashable {
    // MARK: - Properties

    /// The number of the synchronization attempt.
    let attempt: Int

    /// The identifier key of the conversation the attempt applies to.
    let conversationIDKey: String

    /// The date of the attempt.
    let date: Date

    /// Cooldown durations for exponential backoff (seconds).
    private static let cooldowns: [TimeInterval] = [3, 15, 60]

    // MARK: - Computed Properties

    /// A Boolean value that indicates whether the record's cooldown has elapsed.
    var isExpired: Bool {
        TimeInterval(abs(date.seconds(from: .now))) >= Self.cooldowns[
            min(attempt - 1, Self.cooldowns.count - 1)
        ]
    }

    // MARK: - Init

    /// Creates a synchronization record with the given properties.
    ///
    /// - Parameters:
    ///   - conversationIDKey: The identifier key of the conversation the attempt applies to.
    ///   - attempt: The number of the synchronization attempt.
    ///   - date: The date of the attempt.
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

    /// Returns a Boolean value that indicates whether two records apply to the same conversation.
    static func == (
        left: Self,
        right: Self
    ) -> Bool {
        left.conversationIDKey == right.conversationIDKey
    }

    // MARK: - Hashable Conformance

    /// Hashes the record's conversation identifier key.
    func hash(into hasher: inout Hasher) {
        hasher.combine(conversationIDKey)
    }
}
