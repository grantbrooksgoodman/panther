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
    let conversationObserver: ConversationObserverService
    let conversationSync: ConversationSyncService
}
