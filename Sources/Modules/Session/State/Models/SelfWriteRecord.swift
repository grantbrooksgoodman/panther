//
//  SelfWriteRecord.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import Networking

/// A record of a recent local write to a conversation, used to distinguish the app's own writes
/// from remote changes.
struct SelfWriteRecord: Hashable {
    // MARK: - Properties

    /// The identifier of the conversation that was written.
    let conversationID: ConversationID

    /// The date of the write.
    let date: Date

    // MARK: - Computed Properties

    /// A Boolean value that indicates whether the record has expired.
    var isExpired: Bool {
        abs(date.seconds(from: .now)) >= 10
    }

    // MARK: - Init

    /// Creates a self-write record for the given conversation.
    ///
    /// - Parameters:
    ///   - conversationID: The identifier of the conversation that was written.
    ///   - date: The date of the write.
    init(
        _ conversationID: ConversationID,
        date: Date = .now
    ) {
        self.conversationID = conversationID
        self.date = date
    }
}
