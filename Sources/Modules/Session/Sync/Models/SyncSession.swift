//
//  SyncSession.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// The container for a session's conversation synchronization services.
struct SyncSession {
    // MARK: - Properties

    /// The service that observes a conversation for real-time updates.
    let conversationObserver: ConversationObserverService

    // MARK: - Computed Properties

    /// The service that synchronizes a conversation with its server state.
    var conversationSync: ConversationSyncService {
        .init()
    }
}
