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

    var containsBlockedUser: Bool {
        @Dependency(\.clientSession.user.currentUser) var currentUser: User?
        guard let currentUser else { return false }
        return (currentUser.blockedUserIDs ?? []).containsAnyString(in: users.map(\.id))
    }

    // TODO: Audit this – contains(where:) might be better.
    var containsCurrentUser: Bool {
        users.map(\.id).allSatisfy { $0 == User.currentUserID }
    }

    var isMock: Bool {
        guard contact.id.isBlank,
              contact.lastName.isBlank,
              contact.phoneNumbers.isEmpty,
              contact.imageData == nil,
              numberPairs.count == 1,
              let firstNumberPair = numberPairs.first,
              firstNumberPair.users.count == 1,
              let firstUser = firstNumberPair.users.first,
              firstUser.id.isBlank,
              firstUser.conversationIDs == nil,
              firstUser.languageCode.isBlank,
              firstUser.pushTokens == nil,
              firstUser.blockedUserIDs == nil else { return false }
        return true
    }

    var isSelected: Bool {
        @Dependency(\.chatPageViewService.recipientBar?.contactSelectionUI.selectedContactPairs) var selectedContactPairs: [ContactPair]?
        return (selectedContactPairs ?? []).contains(self)
    }

    var users: [User] { numberPairs.flatMap(\.users) }

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
                            aiEnhancedTranslationsEnabled: false,
                            blockedUserIDs: nil,
                            conversationIDs: nil,
                            isPenPalsParticipant: false,
                            languageCode: "",
                            lastSignedIn: nil,
                            messageRecipientConsentRequired: false,
                            phoneNumber: .init(""),
                            previousLanguageCodes: nil,
                            pushTokens: nil
                        ),
                    ]
                ),
            ]
        )
    }

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
                    users: [user]
                ),
            ]
        )
    }
}
