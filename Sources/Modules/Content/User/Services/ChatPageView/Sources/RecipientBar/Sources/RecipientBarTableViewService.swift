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

public final class RecipientBarTableViewService {
    // MARK: - Types

    public struct TableViewSection {
        public let letter: String
        public let contactPairs: [ContactPair]
    }

    // MARK: - Dependencies

    @Dependency(\.clientSession.user.currentUser?.conversations) private var conversations: [Conversation]?
    @Dependency(\.commonServices.penPals) private var penPalsService: PenPalsService
    @Dependency(\.chatPageViewService.recipientBar) private var service: RecipientBarService?

    // MARK: - Properties

    private let viewController: ChatPageViewController

    private var contactPairs: [ContactPair]?
    private var currentQuery: String?
    private var queriedContactPairs = [ContactPair]()

    // MARK: - Computed Properties

    public var sections: [TableViewSection] { getSections() }

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Reload Data

    public func reloadData() {
        guard contactPairs != nil else {
            Task.background(delayedBy: .seconds(1)) { @MainActor in
                resolveContactPairs()
                _reloadData()
            }

            return
        }

        _reloadData()
    }

    // MARK: - Resolve Contact Pairs

    public func resolveContactPairs() {
        contactPairs = getContactPairs() ?? []
    }

    // MARK: - Set Query

    public func setQuery(_ query: String) {
        guard let recipientBarView = service?.layout.recipientBarView,
              let tableView = service?.layout.tableView else { return }

        currentQuery = query.isBlank ? nil : query
        guard !query.isBlank else {
            tableView.alpha = 0
            if UIApplication.v26FeaturesEnabled { viewController.messagesCollectionView.alpha = 1 }
            reloadData()
            return
        }

        let contactPairs = contactPairs ?? []
        queriedContactPairs = query.isZero ? contactPairs : contactPairs.queried(by: query)

        tableView.frame.origin.y = recipientBarView.frame.maxY
        tableView.alpha = 1
        tableView.reloadData()

        guard UIApplication.v26FeaturesEnabled else { return }
        viewController.messagesCollectionView.alpha = 0
    }

    // MARK: - Auxiliary

    private func getContactPairs() -> [ContactPair]? {
        @Persistent(.contactPairArchive) var knownUsers: [ContactPair]?

        if let knownUsers,
           let unknownUsers = conversations?
           .visibleForCurrentUser
           .compactMap(\.users)
           .reduce([], +)
           .filter({ !knownUsers.users.contains($0) && !penPalsService.isObfuscatedPenPalWithCurrentUser($0) })
           .map({ ContactPair.withUser($0) }) {
            return (knownUsers + unknownUsers).uniquedByPhoneNumber
        }

        return knownUsers
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

        queriedContactPairs = currentQuery == nil || currentQuery?.isZero == true ? contactPairs : contactPairs.queried(by: currentQuery!)
        tableView.reloadData()
        QueriedContactPairCache.canWriteToCache = true // NIT: May need to toggle this value when NewChatPageView disappears.
    }
}

private extension String {
    var isZero: Bool { lowercasedTrimmingWhitespaceAndNewlines == "0" }
}
