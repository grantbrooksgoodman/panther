//
//  RecipientBarTableViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 12/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/// The service that manages the recipient bar's contact suggestions table.
///
/// ``RecipientBarTableViewService`` resolves the contacts that can be added as recipients –
/// combining the user's known contacts with the participants of their existing conversations –
/// and groups them into alphabetical sections. It also filters the suggestions by the text the
/// user types.
///
/// Entering the text that selects ChatGPT suggests ChatGPT in place
/// of the user's contacts.
@MainActor
final class RecipientBarTableViewService {
    // MARK: - Types

    /// A group of contact pairs sharing a section heading in the suggestions table.
    struct TableViewSection {
        /// The section's heading letter.
        let letter: String

        /// The contact pairs in the section.
        let contactPairs: [ContactPair]
    }

    // MARK: - Dependencies

    @Dependency(\.commonServices.chatGPT) private var chatGPTService: ChatGPTService
    @Dependency(\.clientSession.entity.user.currentUser?.conversations) private var conversations: [Conversation]?
    @Dependency(\.chatPageViewService.recipientBar) private var service: RecipientBarService?

    // MARK: - Properties

    private static let coalescer = SingleSlotCoalescer<[ContactPair], Never>()

    private let viewController: ChatPageViewController

    private var chatGPTContactPair: ContactPair?
    private var contactPairs: [ContactPair]?
    private var currentQuery: String?
    private var queriedContactPairs = [ContactPair]()

    // MARK: - Computed Properties

    /// The current suggestions, grouped into alphabetical sections and sorted by last name.
    var sections: [TableViewSection] {
        getSections()
    }

    // MARK: - Init

    /// Creates the service, binding it to the given chat page view controller.
    ///
    /// - Parameter viewController: The chat page's messages view controller.
    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Reload Data

    /// Reloads the suggestions table, resolving the available contacts first if they have not yet
    /// been resolved.
    func reloadData() {
        guard contactPairs != nil else {
            Task {
                await resolveContactPairs()
                _reloadData()
            }

            return
        }

        _reloadData()
    }

    // MARK: - Resolve Contact Pairs

    /// Resolves the contacts that can be added as recipients.
    ///
    /// The resolved set combines the user's known contacts with the
    /// participants of their visible conversations, excluding ChatGPT
    /// and participants whose identity is obfuscated in a PenPals
    /// conversation, and removes duplicates by phone number.
    ///
    /// Concurrent calls coalesce onto a single in-flight resolution.
    func resolveContactPairs() async {
        @Persistent(.contactPairArchive) var contactPairArchive: [ContactPair]?
        let conversations = conversations
        let knownContactPairs = contactPairArchive ?? []

        contactPairs = await Self.coalescer { () async -> [ContactPair] in
            await Task.detached(priority: .utility) {
                guard !knownContactPairs.isEmpty,
                      let visibleConversations = conversations?.filter(\.isVisibleForCurrentUser) else {
                    return knownContactPairs.uniquedByPhoneNumber
                }

                let knownUserIDs = Set(knownContactPairs.userIDs)

                var obfuscatedUserIDs = Set<String>()
                var seenUserIDs = Set<String>()
                var unknownUsers = [User]()

                for conversation in visibleConversations {
                    if conversation.metadata.isPenPalsConversation {
                        let sharingIDs = Set(
                            (conversation.participantsSharingPenPalsDataWithCurrentUser ?? []).map(\.userID)
                        )

                        obfuscatedUserIDs.formUnion(
                            conversation
                                .participants
                                .lazy
                                .map(\.userID)
                                .filter { !sharingIDs.contains($0) }
                        )
                    }

                    unknownUsers += conversation
                        .users?
                        .filter {
                            !$0.isChatGPT &&
                                !knownUserIDs.contains($0.id) &&
                                seenUserIDs.insert($0.id).inserted
                        } ?? []
                }

                let unknownContactPairs = unknownUsers
                    .filter { !obfuscatedUserIDs.contains($0.id) }
                    .map { ContactPair.withUser($0) }

                return (knownContactPairs + unknownContactPairs).uniquedByPhoneNumber
            }.value
        }
    }

    // MARK: - Set Query

    /// Filters the suggestions by the given query and shows or hides the table accordingly.
    ///
    /// A blank query hides the table and restores the message list; a
    /// non-blank query shows the filtered suggestions in place of the
    /// message list. The query that selects ChatGPT shows ChatGPT as
    /// the only suggestion, creating ChatGPT's user account if it does
    /// not exist.
    ///
    /// - Parameter query: The text to filter the suggestions by.
    func setQuery(_ query: String) {
        guard let recipientBarView = service?.layout.recipientBarView,
              let tableView = service?.layout.tableView else { return }

        currentQuery = query.isBlank ? nil : query
        guard !query.isBlank else {
            tableView.alpha = 0
            viewController.messageInputBar.alpha = 1
            viewController.messagesCollectionView.alpha = 1
            reloadData()
            return
        }

        queriedContactPairs = filteredContactPairs(for: query)
        if chatGPTService.isRecipientQuery(query),
           chatGPTContactPair == nil {
            resolveChatGPTContactPair()
        }

        tableView.frame.origin.y = recipientBarView.frame.maxY
        tableView.alpha = 1
        tableView.reloadData()

        viewController.messageInputBar.alpha = 0
        viewController.messagesCollectionView.alpha = 0
    }

    // MARK: - Auxiliary

    private func filteredContactPairs(for query: String?) -> [ContactPair] {
        guard let query,
              !query.isZero else { return contactPairs ?? [] }

        guard !chatGPTService.isRecipientQuery(query) else {
            return chatGPTContactPair.map { [$0] } ?? []
        }

        return (contactPairs ?? []).queried(by: query)
    }

    private func getSections() -> [TableViewSection] {
        func sortedByLastName(_ contactPairs: [ContactPair]) -> [ContactPair] {
            contactPairs.unique.sorted(by: { $0.contact.absoluteLastName < $1.contact.absoluteLastName })
        }

        let dictionary: Dictionary = .init(grouping: queriedContactPairs.unique, by: { $0.contact.tableViewSectionTitle })
        let sortedKeys = Array(dictionary.keys).alphabeticallySorted
        return sortedKeys.map { TableViewSection(
            letter: $0,
            contactPairs: sortedByLastName(dictionary[$0]!)
        ) }
    }

    private func _reloadData() {
        guard let contactPairs,
              !contactPairs.isEmpty,
              let recipientBarView = service?.layout.recipientBarView,
              let tableView = service?.layout.tableView else { return }

        if tableView.dataSource == nil { tableView.dataSource = recipientBarView }
        if tableView.delegate == nil { tableView.delegate = recipientBarView }

        queriedContactPairs = filteredContactPairs(for: currentQuery)
        tableView.reloadData()
        QueriedContactPairCache.canWriteToCache = true // NIT: May need to toggle this value when NewChatPageView disappears.
    }

    private func resolveChatGPTContactPair() {
        Task {
            do throws(Exception) {
                chatGPTContactPair = try await chatGPTService.resolveContactPair()
                chatGPTService.prewarm()

                guard let currentQuery,
                      chatGPTService.isRecipientQuery(currentQuery) else { return }
                setQuery(currentQuery)
            } catch {
                Logger.log(
                    error,
                    with: .toast
                )
            }
        }
    }
}

private extension String {
    var isZero: Bool {
        lowercasedTrimmingWhitespaceAndNewlines == "0"
    }
}
