//
//  Persistent+NetworkingExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension Persistent {
    convenience init(_ conversationArchiveServiceKey: UserDefaultsKey.ConversationArchiveServiceDefaultsKey) {
        self.init(.conversationArchiveService(conversationArchiveServiceKey))
    }
}
