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
    /// Merges the given conversations into the set, replacing any existing conversations that
    /// share a key.
    ///
    /// - Parameter conversations: The conversations to merge in.
    mutating func merge(with conversations: any Collection<Conversation>) {
        let incomingKeys = conversations.map(\.id.key)
        self = filter { !incomingKeys.contains($0.id.key) }
        formUnion(conversations)
    }
}

extension Set<User.DataType> {
    /// A set containing every user data type.
    static var allDataTypes: Set<User.DataType> {
        Set(User.DataType.allCases)
    }
}
