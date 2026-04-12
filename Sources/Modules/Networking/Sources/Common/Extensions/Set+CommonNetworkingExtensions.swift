//
//  Set+CommonNetworkingExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension Set<Conversation> {
    // NIT: May be inefficient.
    mutating func merge(with conversations: any Collection<Conversation>) {
        let incomingKeys = conversations.map(\.id.key)
        self = filter { !incomingKeys.contains($0.id.key) }
        formUnion(conversations)
    }
}
