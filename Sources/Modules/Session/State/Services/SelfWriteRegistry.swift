//
//  SelfWriteRegistry.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

/// A registry that tracks recent local writes to conversations, so remote observers can ignore the
/// app's own writes.
enum SelfWriteRegistry {
    // MARK: - Properties

    private static let records = LockIsolated(Set<SelfWriteRecord>())

    // MARK: - Methods

    /// Returns a Boolean value that indicates whether a recent, unexpired write is recorded for the
    /// given conversation.
    ///
    /// - Parameter conversationID: The identifier of the conversation to check.
    ///
    /// - Returns: `true` if a recent write is recorded; otherwise, `false`.
    static func contains(_ conversationID: ConversationID) -> Bool {
        records.wrappedValue.contains {
            $0.conversationID == conversationID &&
                !$0.isExpired
        }
    }

    /// Records a local write for the given conversation.
    ///
    /// - Parameter conversationID: The identifier of the conversation that was written.
    static func record(_ conversationID: ConversationID) {
        records.projectedValue.withValue {
            $0 = $0.filter { !$0.isExpired }
            $0.insert(.init(conversationID))
        }
    }
}
