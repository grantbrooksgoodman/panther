//
//  Persistent+CommonNetworkingExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension Persistent {
    convenience init(
        _ conversationArchiveServiceKey: PersistentStorageKey.ConversationArchiveServiceStorageKey
    ) {
        self.init(.conversationArchiveService(conversationArchiveServiceKey))
    }

    convenience init(
        _ messageArchiveServiceKey: PersistentStorageKey.MessageArchiveServiceStorageKey
    ) {
        self.init(.messageArchiveService(messageArchiveServiceKey))
    }
}
