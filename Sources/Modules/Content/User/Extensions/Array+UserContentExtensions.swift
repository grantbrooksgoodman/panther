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

extension [ContactPair] {
    // MARK: - Properties

    /// The contact pairs with duplicates removed by phone number, keeping the first occurrence of
    /// each.
    var uniquedByPhoneNumber: [ContactPair] {
        var contactPairs = [ContactPair]()
        var seenNumbers = Set<String>()

        for contactPair in self {
            guard !contactPair
                .compiledNumberStrings
                .contains(where: seenNumbers.contains) else { continue }

            contactPairs.append(contactPair)
            seenNumbers.formUnion(contactPair.compiledNumberStrings)
        }

        return contactPairs
    }

    /// The user identifiers across all of the contact pairs.
    var userIDs: [String] {
        flatMap(\.userIDs)
    }

    /// The users across all of the contact pairs.
    var users: [User] {
        flatMap(\.users)
    }

    // MARK: - Methods

    /// Returns the contact pairs matching the given search term, excluding those already selected
    /// as recipients.
    ///
    /// Matches against each contact's name and phone numbers. Results are cached in memory per
    /// search term.
    ///
    /// - Parameter searchTerm: The term to filter the contact pairs by.
    ///
    /// - Returns: The matching contact pairs, excluding any currently selected as recipients.
    @MainActor
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

extension [Conversation] {
    // MARK: - Properties

    /// The unique conversations among the array which are visible for the current user,
    /// sorted by latest message sent date, and hydrated with system messages.
    var filteredAndSorted: [Conversation] {
        visibleForCurrentUser
            .sortedByLatestMessageSentDate
            .unique
            .map(\.filteringSystemMessages)
    }

    // MARK: - Methods

    /// Returns the visible conversations matching the given search term.
    ///
    /// Matches against each conversation's name, title, and message text. Results are cached in
    /// memory per search term.
    ///
    /// - Parameter searchTerm: The term to filter the conversations by.
    ///
    /// - Returns: The matching conversations that are visible to the current user.
    @MainActor
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
                .messages else {
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

extension [Message] {
    // MARK: - Properties

    /// The messages with system messages removed.
    var filteringSystemMessages: [Message] {
        filter { !$0.isSystemMessage }
    }

    /// The messages sorted from oldest to newest.
    var sortedByAscendingSentDate: [Message] {
        sorted(by: { $0.sentDate < $1.sentDate })
    }

    /// The messages sorted from newest to oldest.
    var sortedByDescendingSentDate: [Message] {
        sorted(by: { $0.sentDate > $1.sentDate })
    }

    // MARK: - Methods

    /// Returns the messages merged with the given activities' system messages, de-duplicated and
    /// sorted from oldest to newest.
    ///
    /// - Parameter activities: The activities whose system messages to merge in.
    ///
    /// - Returns: The combined, sorted messages.
    func hydrated(with activities: [Activity]?) -> [Message] {
        guard let activities,
              !activities.allSatisfy({ $0 == .empty }) else { return self }
        return (self + activities.map(\.message))
            .uniquedByID
            .sortedByAscendingSentDate
    }

    /// Returns the messages limited to those sent after the current user joined the conversation,
    /// always including consent messages.
    ///
    /// - Parameter activities: The conversation's activities, used to determine when the current
    ///   user joined.
    ///
    /// - Returns: The filtered messages.
    func offsetFromCurrentUserAdditionDate(
        activities: [Activity]?
    ) -> [Message] {
        guard let currentUserAddedActivity = activities?
            .last(where: \.action.isCurrentUserAdded) else { return self }
        return filter {
            $0.isConsentMessage || $0.sentDate >= currentUserAddedActivity.date
        }
    }
}

extension [MessageRecipientConsentAcknowledgementData] {
    /// The consent acknowledgement record belonging to the current user, if any.
    var firstWithCurrentUserID: MessageRecipientConsentAcknowledgementData? {
        first(where: { $0.userID == User.currentUserID })
    }
}

extension [Participant] {
    /// The participant representing the current user, if any.
    var firstWithCurrentUserID: Participant? {
        first(where: { $0.userID == User.currentUserID })
    }
}

extension [PenPalsSharingData] {
    /// A Boolean value that indicates whether every other participant shares their PenPals data
    /// with the current user.
    var allShareWithCurrentUser: Bool {
        guard let firstWithCurrentUserID else { return false }
        return filter { $0.userID != firstWithCurrentUserID.userID }
            .allSatisfy { Set($0.sharesDataWithUserIDs ?? []).contains(firstWithCurrentUserID.userID) }
    }

    /// A Boolean value that indicates whether every participant shares their PenPals data with
    /// every other participant.
    var allShareWithEachOther: Bool {
        let userIDs = Set(map(\.userID))
        return allSatisfy { datum in
            let otherUserIDs = userIDs.subtracting([datum.userID])
            return Set(datum.sharesDataWithUserIDs ?? []) == otherUserIDs
        }
    }

    /// The current user's PenPals data-sharing record, if any.
    var firstWithCurrentUserID: PenPalsSharingData? {
        first(where: { $0.userID == User.currentUserID })
    }
}

extension [String] {
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

extension [User] {
    /// The users with duplicates removed by identifier, keeping the first occurrence of each.
    var uniquedByID: [User] {
        var set = Set<String>()
        return filter { set.insert($0.id).inserted }
    }
}
