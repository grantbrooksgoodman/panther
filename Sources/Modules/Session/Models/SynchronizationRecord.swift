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

    let conversationID: ConversationID
    let date: Date

    // MARK: - Computed Properties

    var isExpired: Bool { abs(date.seconds(from: .now)) >= 3 }

    // MARK: - Init

    init(
        _ conversationID: ConversationID,
        date: Date = .now
    ) {
        self.conversationID = conversationID
        self.date = date
    }
}
