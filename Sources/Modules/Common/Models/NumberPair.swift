//
//  NumberPair.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

// NIT: Need to either use phone number strings or conform PhoneNumber to not auto-resolve a calling code.
struct NumberPair: Codable, Hashable {
    // MARK: - Properties

    let phoneNumber: PhoneNumber
    let userIDs: [String]

    // MARK: - Computed Properties

    /// Resolves users from the session store using this number pair's `userIDs`.
    var users: [User] {
        @Dependency(\.clientSession.store) var sessionStore: SessionStore
        return userIDs.compactMap { sessionStore.users[$0] }
    }

    // MARK: - Init

    init(
        phoneNumber: PhoneNumber,
        userIDs: [String]
    ) {
        assert(
            !userIDs.isEmpty,
            "Initialized NumberPair with empty userIDs array"
        )

        self.phoneNumber = phoneNumber
        self.userIDs = userIDs
    }

    // MARK: - Hashable Conformance

    func hash(into hasher: inout Hasher) {
        hasher.combine(phoneNumber)
        hasher.combine(userIDs)
    }
}
