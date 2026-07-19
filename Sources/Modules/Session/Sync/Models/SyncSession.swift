//
//  SyncSession.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

struct SyncSession {
    // MARK: - Properties

    let conversationObserver: ConversationObserverService

    // MARK: - Computed Properties

    var conversationSync: ConversationSyncService {
        .init()
    }
}
