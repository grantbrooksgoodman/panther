//
//  RecipientBar+UITableViewDataSource.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 12/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import Redux

extension RecipientBar: UITableViewDataSource {
    // MARK: - Cell for Row at Index Path

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        @Dependency(\.chatPageViewService.recipientBar?.tableView) var tableViewService: RecipientBarTableViewService?

        typealias Strings = AppConstants.Strings.ChatPageViewService.RecipientBarService.Layout
        let cell = tableView.dequeueReusableCell(withIdentifier: Strings.tableViewCellReuseIdentifier, for: indexPath)

        guard let contactPair = tableViewService?.sections.itemAt(indexPath.section)?.contactPairs.itemAt(indexPath.row) else { return cell }

        cell.contentConfiguration = UIHostingConfiguration { ContactPairCellView(contactPair: contactPair) }
        cell.isUserInteractionEnabled = !contactPair.containsCurrentUser

        return cell
    }

    // MARK: - Number of Rows in Section

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        @Dependency(\.chatPageViewService.recipientBar?.tableView) var tableViewService: RecipientBarTableViewService?
        return tableViewService?.sections.itemAt(section)?.contactPairs.count ?? 0
    }

    // MARK: - Number of Sections

    public func numberOfSections(in tableView: UITableView) -> Int {
        @Dependency(\.chatPageViewService.recipientBar?.tableView) var tableViewService: RecipientBarTableViewService?
        return tableViewService?.sections.count ?? 0
    }

    // MARK: - Title for Header in Section

    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        @Dependency(\.chatPageViewService.recipientBar?.tableView) var tableViewService: RecipientBarTableViewService?
        return tableViewService?.sections.itemAt(section)?.letter
    }
}
