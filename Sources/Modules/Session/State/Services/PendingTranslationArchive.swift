//
//  PendingTranslationArchive.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// Holds hosted-archive fan-out entries for deferred-archival
/// translations until the message commit that carries them drains
/// them into its payload.
///
/// Recording is idempotent – re-recording a hosting key overwrites
/// the previous entry. Entries drained into a commit that fails are
/// re-recorded by the retry's translate pass.
enum PendingTranslationArchive {
    // MARK: - Properties

    private static let entries = LockIsolated([String: (key: String, value: Any)]())

    // MARK: - Methods

    /// Removes and returns the archive entry recorded for the given hosting key, if any.
    ///
    /// - Parameter hostingKey: The hosting key whose entry to drain.
    ///
    /// - Returns: The archive entry for the hosting key, or `nil` if none is recorded.
    static func drain(
        for hostingKey: String
    ) -> (key: String, value: Any)? {
        entries.projectedValue.withValue {
            $0.removeValue(forKey: hostingKey)
        }
    }

    /// Records the given archive entry for the given hosting key, replacing any existing entry.
    ///
    /// - Parameters:
    ///   - entry: The archive entry to record.
    ///   - hostingKey: The hosting key to record the entry for.
    static func record(
        _ entry: (key: String, value: Any),
        for hostingKey: String
    ) {
        entries.projectedValue.withValue { $0[hostingKey] = entry }
    }
}
