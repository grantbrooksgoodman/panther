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

    static func drain(
        for hostingKey: String
    ) -> (key: String, value: Any)? {
        entries.projectedValue.withValue {
            $0.removeValue(forKey: hostingKey)
        }
    }

    static func record(
        _ entry: (key: String, value: Any),
        for hostingKey: String
    ) {
        entries.projectedValue.withValue { $0[hostingKey] = entry }
    }
}
