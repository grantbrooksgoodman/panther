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

/* 3rd-party */
import Redux

public final class RecipientBarTableViewService {
    // MARK: - Types

    public struct TableViewSection {
        public let letter: String
        public let contactPairs: [ContactPair]
    }

    // MARK: - Dependencies

    @Dependency(\.chatPageViewService.recipientBar) private var service: RecipientBarService?

    // MARK: - Properties

    private let viewController: ChatPageViewController

    @Persistent(.contactPairArchive) private var contactPairs: [ContactPair]?
    private var queriedContactPairs = [ContactPair]()

    // MARK: - Computed Properties

    public var sections: [TableViewSection] { getSections() }

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
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

    // MARK: - Set Query

    public func setQuery(_ query: String) {
        guard let recipientBarView = service?.layout.recipientBarView,
              let tableView = service?.layout.tableView else { return }

        guard !query.isBlank else {
            tableView.alpha = 0
            reloadData()
            return
        }

        queriedContactPairs = (contactPairs ?? [])
            .filter { "\($0.contact)".lowercased().contains(query.lowercased()) }
            .filter { !(service?.contactSelectionUI.selectedContactPairs ?? []).contains($0) }

        tableView.frame.origin.y = recipientBarView.frame.maxY
        tableView.alpha = 1
        tableView.reloadData()
    }

    // MARK: - Auxiliary

    private func getSections() -> [TableViewSection] {
        func groupTitle(for contact: Contact) -> String {
            guard contact.lastName.hasPrefix("+"),
                  !contact.lastName.digits.isBlank else { return .init(contact.lastName.prefix(1)) }
            return "#"
        }

        func sortedByLastName(_ contactPairs: [ContactPair]) -> [ContactPair] {
            contactPairs.unique.sorted(by: { $0.contact.lastName < $1.contact.lastName })
        }

        let dictionary: Dictionary = .init(grouping: queriedContactPairs.unique, by: { groupTitle(for: $0.contact) })
        let sortedKeys = Array(dictionary.keys).alphabeticallySorted
        return sortedKeys.map { TableViewSection(
            letter: $0,
            contactPairs: sortedByLastName(dictionary[$0]!)
        ) }
    }
}
