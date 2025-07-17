//
//  Array+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension Array where Element == ContactPair {
    // MARK: - Properties

    var uniquedByPhoneNumber: [ContactPair] {
        var contactPairs = [ContactPair]()

        for contactPair in self {
            let phoneNumbers = contactPairs.map(\.contact.phoneNumbers.compiledNumberStrings).reduce([], +)
            guard !contactPair.contact.phoneNumbers.compiledNumberStrings.contains(where: phoneNumbers.contains) else { continue }
            contactPairs.append(contactPair)
        }

        return contactPairs
    }

    var users: [User] { map(\.users).reduce([], +) }

    // MARK: - Methods

    func queried(by searchTerm: String) -> [ContactPair] {
        @Dependency(\.chatPageViewService.recipientBar?.contactSelectionUI) var recipientBarContactSelectionUIService: RecipientBarContactSelectionUIService?

        guard !searchTerm.isEmpty else { return self } // Still want to capture pure whitespace, hence .isEmpty and not .isBlank.
        let selectedContactPairs = Set(recipientBarContactSelectionUIService?.selectedContactPairs ?? [])

        if let cachedValue = QueriedContactPairCache.cachedContactPairsForSearchTerms?[searchTerm] {
            return cachedValue.filter { !selectedContactPairs.contains($0) }
        }

        let queriedContactPairs = filter { contactPair in
            let contact = contactPair.contact
            let validTerms = [
                contact.fullName,
                contact.firstName,
                contact.lastName,
            ] + contact.phoneNumbers.compiledNumberStrings

            return validTerms.contains { $0.lowercasedTrimmingWhitespaceAndNewlines.contains(searchTerm.lowercasedTrimmingWhitespaceAndNewlines) }
        }

        if QueriedContactPairCache.canWriteToCache {
            var cachedContactPairsForSearchTerms = QueriedContactPairCache.cachedContactPairsForSearchTerms ?? [:]
            cachedContactPairsForSearchTerms[searchTerm] = queriedContactPairs
            QueriedContactPairCache.cachedContactPairsForSearchTerms = cachedContactPairsForSearchTerms
        }

        return queriedContactPairs.filter { !selectedContactPairs.contains($0) }
    }
}

public extension Array where Element == Conversation {
    // MARK: - Properties

    /// The unique conversations among the array which are visible for the current user, sorted by latest message sent date.
    var filteredAndSorted: [Conversation] {
        visibleForCurrentUser.sortedByLatestMessageSentDate.unique
    }

    // MARK: - Methods

    func queried(by searchTerm: String) -> [Conversation] {
        let searchTerm = searchTerm.lowercasedTrimmingWhitespaceAndNewlines
        guard !searchTerm.isBlank else { return self }

        if let cachedValue = QueriedConversationCache.cachedConversationsForSearchTerms?[searchTerm] {
            return cachedValue.visibleForCurrentUser
        }

        func satisfiesConstraints(_ conversation: Conversation) -> Bool {
            let metadataContainsSearchTerm = conversation.metadata.name.lowercasedTrimmingWhitespaceAndNewlines.contains(searchTerm)
            guard let messages = conversation.messages else { return metadataContainsSearchTerm }
            let messagesContainsSearchTerm = messages.contains(where: { $0.textContains(searchTerm) })
            return messagesContainsSearchTerm || metadataContainsSearchTerm
        }

        let queriedConversations = filter { satisfiesConstraints($0) }

        var cachedConversationsForSearchTerms = QueriedConversationCache.cachedConversationsForSearchTerms ?? [:]
        cachedConversationsForSearchTerms[searchTerm] = queriedConversations
        QueriedConversationCache.cachedConversationsForSearchTerms = cachedConversationsForSearchTerms

        return queriedConversations
    }
}

public extension Array where Element == Message {
    var sortedByAscendingSentDate: [Message] { sorted(by: { $0.sentDate < $1.sentDate }) }
}

public extension Array where Element == MessageRecipientConsentAcknowledgementData {
    var firstWithCurrentUserID: MessageRecipientConsentAcknowledgementData? {
        @Dependency(\.clientSession.user.currentUser?.id) var currentUserID: String?
        @Persistent(.currentUserID) var fallbackCurrentUserID: String?
        guard let resolvedCurrentUserID = currentUserID ?? fallbackCurrentUserID else { return nil }
        return first(where: { $0.userID == resolvedCurrentUserID })
    }
}

public extension Array where Element == Participant {
    var firstWithCurrentUserID: Participant? {
        @Dependency(\.clientSession.user.currentUser?.id) var currentUserID: String?
        @Persistent(.currentUserID) var fallbackCurrentUserID: String?
        guard let resolvedCurrentUserID = currentUserID ?? fallbackCurrentUserID else { return nil }
        return first(where: { $0.userID == resolvedCurrentUserID })
    }
}

public extension Array where Element == PenPalsSharingData {
    var allShareWithCurrentUser: Bool {
        guard let firstWithCurrentUserID else { return false }
        return filter { $0.userID != firstWithCurrentUserID.userID }
            .allSatisfy { Set($0.sharesDataWithUserIDs ?? []).contains(firstWithCurrentUserID.userID) }
    }

    var allShareWithEachOther: Bool {
        let userIDs = Set(map(\.userID))
        return allSatisfy { datum in
            let otherUserIDs = userIDs.subtracting([datum.userID])
            return Set(datum.sharesDataWithUserIDs ?? []) == otherUserIDs
        }
    }

    var firstWithCurrentUserID: PenPalsSharingData? {
        @Dependency(\.clientSession.user.currentUser?.id) var currentUserID: String?
        @Persistent(.currentUserID) var fallbackCurrentUserID: String?
        guard let resolvedCurrentUserID = currentUserID ?? fallbackCurrentUserID else { return nil }
        return first(where: { $0.userID == resolvedCurrentUserID })
    }
}

public extension Array where Element == String {
    /// Sorts the array with alphabetically-prefixed strings taking priority.
    var alphabeticallySorted: [String] {
        var alphabetical = [String]()
        var notAlphabetical = [String]()

        for string in self {
            guard let firstCharacter = string.lowercasedTrimmingWhitespaceAndNewlines.first,
                  firstCharacter.isLetter else {
                notAlphabetical.append(string)
                continue
            }

            alphabetical.append(string)
        }

        return alphabetical.sorted() + notAlphabetical.sorted()
    }
}
