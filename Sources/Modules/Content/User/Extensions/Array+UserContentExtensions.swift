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

extension Array where Element == ContactPair {
    // MARK: - Properties

    var uniquedByPhoneNumber: [ContactPair] {
        var contactPairs = [ContactPair]()

        for contactPair in self {
            let phoneNumbers = contactPairs
                .map(\.contact.phoneNumbers.compiledNumberStrings)
                .flatMap { $0 }
            guard !contactPair.contact.phoneNumbers.compiledNumberStrings.contains(where: phoneNumbers.contains) else { continue }
            contactPairs.append(contactPair)
        }

        return contactPairs
    }

    var users: [User] { flatMap(\.users) }

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

extension Array where Element == Conversation {
    // MARK: - Properties

    /// The unique conversations among the array which are visible for the current user,
    /// sorted by latest message sent date, and hydrated with system messages.
    var filteredAndSorted: [Conversation] {
        visibleForCurrentUser
            .map(\.filteringSystemMessages)
            .sortedByLatestMessageSentDate
            .unique
            .map(\.withHydratedMessages)
    }

    // MARK: - Methods

    func queried(by searchTerm: String) -> [Conversation] {
        let searchTerm = searchTerm.lowercasedTrimmingWhitespaceAndNewlines
        guard !searchTerm.isBlank else { return self }

        if let cachedValue = QueriedConversationCache.cachedConversationsForSearchTerms?[searchTerm] {
            return cachedValue.visibleForCurrentUser
        }

        func satisfiesConstraints(_ conversation: Conversation) -> Bool {
            let metadataContainsSearchTerm = conversation
                .metadata
                .name
                .lowercasedTrimmingWhitespaceAndNewlines
                .contains(searchTerm)

            // swiftlint:disable:next identifier_name
            let cellViewDataTitleLabelTextContainsSearchTerm = ConversationCellViewData(conversation)?
                .titleLabelText
                .lowercasedTrimmingWhitespaceAndNewlines
                .contains(searchTerm) == true

            guard let messages = conversation
                .withMessagesOffsetFromCurrentUserAdditionDate
                .messages?
                .filteringSystemMessages else {
                return cellViewDataTitleLabelTextContainsSearchTerm || metadataContainsSearchTerm
            }

            let messagesContainsSearchTerm = messages
                .contains(where: { $0.textContains(searchTerm) })

            return cellViewDataTitleLabelTextContainsSearchTerm || messagesContainsSearchTerm || metadataContainsSearchTerm
        }

        let queriedConversations = filter { satisfiesConstraints($0) }

        var cachedConversationsForSearchTerms = QueriedConversationCache.cachedConversationsForSearchTerms ?? [:]
        cachedConversationsForSearchTerms[searchTerm] = queriedConversations
        QueriedConversationCache.cachedConversationsForSearchTerms = cachedConversationsForSearchTerms

        return queriedConversations
    }
}

extension Array where Element == Message {
    // MARK: - Properties

    var filteringSystemMessages: [Message] { filter { !$0.isSystemMessage } }
    var sortedByAscendingSentDate: [Message] { sorted(by: { $0.sentDate < $1.sentDate }) }
    var sortedByDescendingSentDate: [Message] { sorted(by: { $0.sentDate > $1.sentDate }) }

    // MARK: - Methods

    func hydrated(with activities: [Activity]?) -> [Message] {
        guard let activities,
              !activities.allSatisfy({ $0 == .empty }) else { return self }
        return (filteringSystemMessages + activities.map(\.message))
            .uniquedByID
            .sortedByAscendingSentDate
    }
}

extension Array where Element == MessageRecipientConsentAcknowledgementData {
    var firstWithCurrentUserID: MessageRecipientConsentAcknowledgementData? {
        first(where: { $0.userID == User.currentUserID })
    }
}

extension Array where Element == Participant {
    var firstWithCurrentUserID: Participant? {
        first(where: { $0.userID == User.currentUserID })
    }
}

extension Array where Element == PenPalsSharingData {
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
        first(where: { $0.userID == User.currentUserID })
    }
}

extension Array where Element == String {
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

extension Array where Element == User {
    var uniquedByID: [User] {
        var set = Set<String>()
        return filter { set.insert($0.id).inserted }
    }
}
