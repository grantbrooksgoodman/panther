//
//  Persistent+CommonNetworkingExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension Persistent {
    convenience init(_ conversationArchiveServiceKey: UserDefaultsKeyDomain.ConversationArchiveServiceDefaultsKey) {
        self.init(.app(.conversationArchiveService(conversationArchiveServiceKey)))
    }
}
