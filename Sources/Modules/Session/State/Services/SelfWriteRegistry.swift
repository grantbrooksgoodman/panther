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

enum SelfWriteRegistry {
    // MARK: - Properties

    private static let records = LockIsolated(Set<SelfWriteRecord>())

    // MARK: - Methods

    static func contains(_ conversationID: ConversationID) -> Bool {
        records.wrappedValue.contains {
            $0.conversationID == conversationID &&
                !$0.isExpired
        }
    }

    static func record(_ conversationID: ConversationID) {
        records.projectedValue.withValue {
            $0 = $0.filter { !$0.isExpired }
            $0.insert(.init(conversationID))
        }
    }
}
