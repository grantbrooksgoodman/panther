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
/// A phone number paired with the registered users it resolves to.
struct NumberPair: Codable, Hashable {
    // MARK: - Properties

    /// The phone number.
    let phoneNumber: PhoneNumber

    /// The identifiers of the registered users the phone number resolves to.
    let userIDs: [String]

    // MARK: - Computed Properties

    /// The users this number pair's ``userIDs`` resolve to in the session store. Users not
    /// present in the store are omitted.
    var users: [User] {
        @Dependency(\.clientSession.store) var sessionStore: SessionStore
        return userIDs.compactMap { sessionStore.users[$0] }
    }

    // MARK: - Init

    /// Creates a number pair with the given phone number and user identifiers.
    ///
    /// - Parameters:
    ///   - phoneNumber: The phone number.
    ///   - userIDs: The identifiers of the registered users the phone number resolves to. Must
    ///     not be empty.
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

    /// Hashes the pair's phone number and user identifiers.
    func hash(into hasher: inout Hasher) {
        hasher.combine(phoneNumber)
        hasher.combine(userIDs)
    }
}
