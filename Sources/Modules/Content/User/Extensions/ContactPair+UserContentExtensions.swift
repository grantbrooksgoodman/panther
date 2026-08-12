//
//  ContactPair+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 13/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension ContactPair {
    // MARK: - Properties

    /// The compiled number strings of the contact's phone numbers.
    var compiledNumberStrings: [String] {
        contact.phoneNumbers.compiledNumberStrings
    }

    /// A Boolean value that indicates whether the contact pair contains a user the current user
    /// has blocked.
    var containsBlockedUser: Bool {
        @Dependency(\.clientSession.entity.user.currentUser) var currentUser: User?
        guard let currentUser else { return false }
        return (currentUser.blockedUserIDs ?? []).containsAnyString(in: userIDs)
    }

    // TODO: Audit this – contains(where:) might be better.
    /// A Boolean value that indicates whether the contact pair contains only the current user.
    var containsCurrentUser: Bool {
        userIDs.allSatisfy { $0 == User.currentUserID }
    }

    /// A Boolean value that indicates whether the contact pair is a mock, representing an
    /// unresolved recipient entered manually.
    var isMock: Bool {
        guard contact.id.isBlank,
              contact.lastName.isBlank,
              contact.phoneNumbers.isEmpty,
              contact.imageData == nil,
              numberPairs.count == 1,
              let firstNumberPair = numberPairs.first,
              firstNumberPair.userIDs.count == 1,
              firstNumberPair.userIDs.first?.isBlank == true else { return false }
        return true
    }

    /// A Boolean value that indicates whether the contact pair is currently selected as a
    /// recipient.
    @MainActor
    var isSelected: Bool {
        @Dependency(\.chatPageViewService.recipientBar?.contactSelectionUI.selectedContactPairs) var selectedContactPairs: [ContactPair]?
        return (selectedContactPairs ?? []).contains(self)
    }

    /// The user identifiers across the contact pair's number pairs.
    var userIDs: [String] {
        numberPairs.flatMap(\.userIDs)
    }

    /// Resolves users from the session store using this contact pair's user IDs.
    var users: [User] {
        numberPairs.flatMap(\.users)
    }

    // MARK: - Methods

    /// Creates a mock contact pair with the given name, representing an unresolved recipient.
    ///
    /// - Parameter name: The name to display for the recipient.
    ///
    /// - Returns: A mock contact pair.
    static func mock(withName name: String) -> ContactPair {
        .init(
            contact: .init(
                "",
                firstName: name,
                lastName: "",
                phoneNumbers: [],
                imageData: nil
            ),
            numberPairs: [
                .init(
                    phoneNumber: .init(""),
                    userIDs: [""]
                ),
            ]
        )
    }

    /// Creates a contact pair for the given registered user.
    ///
    /// - Parameters:
    ///   - user: The registered user to represent.
    ///   - name: The name to display, or `nil` to use the user's formatted phone number.
    ///
    /// - Returns: A contact pair representing the given user.
    static func withUser(
        _ user: User,
        name: String? = nil
    ) -> ContactPair {
        .init(
            contact: .init(
                "",
                firstName: name ?? user.phoneNumber.formattedString(),
                lastName: "",
                phoneNumbers: [user.phoneNumber],
                imageData: nil
            ),
            numberPairs: [
                .init(
                    phoneNumber: user.phoneNumber,
                    userIDs: [user.id]
                ),
            ]
        )
    }
}
