//
//  ContactPair+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 13/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension ContactPair {
    var containsCurrentUser: Bool {
        @Persistent(.currentUserID) var currentUserID: String?
        return numberPairs.map { $0.users.map(\.id) }.reduce([], +).allSatisfy { $0 == currentUserID }
    }

    var firstUser: User? {
        numberPairs.map(\.users).reduce([], +).first
    }
}
