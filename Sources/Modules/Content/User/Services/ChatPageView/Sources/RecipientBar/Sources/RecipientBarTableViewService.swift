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

@MainActor
final class RecipientBarTableViewService {
    // MARK: - Types

    struct TableViewSection {
        let letter: String
        let contactPairs: [ContactPair]
    }

    // MARK: - Dependencies

    @Dependency(\.clientSession.user.currentUser?.conversations) private var conversations: [Conversation]?
    @Dependency(\.chatPageViewService.recipientBar) private var service: RecipientBarService?

    // MARK: - Properties

    private let viewController: ChatPageViewController

    private var contactPairs: [ContactPair]?
    private var currentQuery: String?
    private var queriedContactPairs = [ContactPair]()

    // MARK: - Computed Properties

    var sections: [TableViewSection] {
        getSections()
    }

    // MARK: - Init

    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Reload Data

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

    func resolveContactPairs() async {
        @Persistent(.contactPairArchive) var contactPairArchive: [ContactPair]?
        let conversations = conversations
        let knownContactPairs = contactPairArchive ?? []

        contactPairs = await Task.detached(priority: .utility) {
            guard !knownContactPairs.isEmpty,
                  let visibleConversations = conversations?.filter(\.isVisibleForCurrentUser) else {
                return knownContactPairs.uniquedByPhoneNumber
            }

            let knownUserIDs = Set(knownContactPairs.users.map(\.id))

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

    // MARK: - Set Query

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

        let contactPairs = contactPairs ?? []
        queriedContactPairs = query.isZero ? contactPairs : contactPairs.queried(by: query)

        tableView.frame.origin.y = recipientBarView.frame.maxY
        tableView.alpha = 1
        tableView.reloadData()

        viewController.messageInputBar.alpha = 0
        viewController.messagesCollectionView.alpha = 0
    }

    // MARK: - Auxiliary

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

        queriedContactPairs = currentQuery == nil || currentQuery?.isZero == true ? contactPairs : contactPairs.queried(by: currentQuery!)
        tableView.reloadData()
        QueriedContactPairCache.canWriteToCache = true // NIT: May need to toggle this value when NewChatPageView disappears.
    }
}

private extension String {
    var isZero: Bool {
        lowercasedTrimmingWhitespaceAndNewlines == "0"
    }
}
