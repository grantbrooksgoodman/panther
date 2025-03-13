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
    @Dependency(\.chatPageViewService.recipientBar) private var service: RecipientBarService?

    // MARK: - Properties

    private let viewController: ChatPageViewController

    private var contactPairs: [ContactPair]?
    private var queriedContactPairs = [ContactPair]()

    // MARK: - Computed Properties

    public var sections: [TableViewSection] { getSections() }

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
        resolveContactPairs()
    }

    // MARK: - Reload Data

    public func reloadData() {
        guard let contactPairs,
              !contactPairs.isEmpty,
              let recipientBarView = service?.layout.recipientBarView,
              let tableView = service?.layout.tableView else { return }

        if tableView.dataSource == nil { tableView.dataSource = recipientBarView }
        if tableView.delegate == nil { tableView.delegate = recipientBarView }

        queriedContactPairs = contactPairs
        tableView.reloadData()
    }

    // MARK: - Resolve Contact Pairs

    public func resolveContactPairs() {
        contactPairs = getContactPairs()
    }

    // MARK: - Set Query

    public func setQuery(_ query: String) {
        guard let recipientBarView = service?.layout.recipientBarView,
              let tableView = service?.layout.tableView else { return }

        guard !query.isBlank else {
            tableView.alpha = 0
            reloadData()
            return
        }

        queriedContactPairs = (contactPairs ?? []).queried(by: query)

        tableView.frame.origin.y = recipientBarView.frame.maxY
        tableView.alpha = 1
        tableView.reloadData()
    }

    // MARK: - Auxiliary

    private func getContactPairs() -> [ContactPair]? {
        @Persistent(.contactPairArchive) var knownUsers: [ContactPair]?

        if let knownUsers,
           let unknownUsers = conversations?
           .visibleForCurrentUser
           .compactMap(\.users)
           .reduce([], +)
           .filter({ !knownUsers.users.contains($0) })
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
}
