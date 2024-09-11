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

public extension ContactPair {
    // MARK: - Properties

    var containsBlockedUser: Bool {
        @Dependency(\.clientSession.user.currentUser) var currentUser: User?
        guard let currentUser else { return false }
        return (currentUser.blockedUserIDs ?? []).containsAnyString(in: users.map(\.id))
    }

    var containsCurrentUser: Bool {
        @Persistent(.currentUserID) var currentUserID: String?
        // TODO: Audit this – contains(where:) might be better.
        return users.map(\.id).allSatisfy { $0 == currentUserID }
    }

    static var empty: ContactPair { mock(withName: "") }

    var isMock: Bool {
        guard contact.id.isBlank,
              contact.lastName.isBlank,
              contact.phoneNumbers.isEmpty,
              contact.imageData == nil,
              numberPairs.count == 1,
              let firstNumberPair = numberPairs.first,
              firstNumberPair.phoneNumber.compiledNumberString.isBlank,
              firstNumberPair.users.count == 1,
              let firstUser = firstNumberPair.users.first,
              firstUser.id.isBlank,
              firstUser.conversationIDs == nil,
              firstUser.languageCode.isBlank,
              firstUser.phoneNumber.compiledNumberString.isBlank,
              firstUser.pushTokens == nil,
              firstUser.blockedUserIDs == nil else { return false }
        return true
    }

    var isSelected: Bool {
        @Dependency(\.chatPageViewService.recipientBar?.contactSelectionUI.selectedContactPairs) var selectedContactPairs: [ContactPair]?
        return (selectedContactPairs ?? []).contains(self)
    }

    var users: [User] { numberPairs.map(\.users).reduce([], +) }

    // MARK: - Methods

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
                    users: [
                        .init(
                            "",
                            blockedUserIDs: nil,
                            conversationIDs: nil,
                            languageCode: "",
                            phoneNumber: .init(""),
                            pushTokens: nil
                        ),
                    ]
                ),
            ]
        )
    }

    static func withUser(_ user: User) -> ContactPair {
        .init(
            contact: .init(
                "",
                firstName: user.phoneNumber.formattedString(),
                lastName: "",
                phoneNumbers: [user.phoneNumber],
                imageData: nil
            ),
            numberPairs: [
                .init(
                    phoneNumber: user.phoneNumber,
                    users: [user]
                ),
            ]
        )
    }
}
