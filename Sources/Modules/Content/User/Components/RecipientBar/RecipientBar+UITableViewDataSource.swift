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

/* Proprietary */
import AppSubsystem

extension RecipientBar: UITableViewDataSource {
    // MARK: - Cell for Row at Index Path

    /// Returns a contact pair cell for the given index path.
    ///
    /// Cells for contact pairs that contain a blocked user, contain the current user, or are
    /// already selected are disabled.
    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        @Dependency(\.chatPageViewService.recipientBar?.tableView) var tableViewService: RecipientBarTableViewService?

        typealias Colors = AppConstants.Colors.ContactPairCellView
        typealias Strings = AppConstants.Strings.ChatPageViewService.RecipientBarService.Layout

        let cell = tableView.dequeueReusableCell(
            withIdentifier: Strings.tableViewCellReuseIdentifier,
            for: indexPath
        )

        guard let contactPair = tableViewService?
            .sections
            .itemAt(indexPath.section)?
            .contactPairs
            .itemAt(indexPath.row) else { return cell }

        cell.contentConfiguration = UIHostingConfiguration {
            ContactPairCellView(contactPair: contactPair)
                .redrawsOnTraitCollectionChange()
        }

        cell.isUserInteractionEnabled = !(
            contactPair.containsBlockedUser ||
                contactPair.containsCurrentUser ||
                contactPair.isSelected
        )

        guard Application.isInPrevaricationMode else { return cell }
        cell.backgroundColor = UIColor(Colors.prevaricationModeBackground)
        return cell
    }

    // MARK: - Number of Rows in Section

    /// Returns the number of contact pairs in the given section.
    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        @Dependency(\.chatPageViewService.recipientBar?.tableView) var tableViewService: RecipientBarTableViewService?
        return tableViewService?.sections.itemAt(section)?.contactPairs.count ?? 0
    }

    // MARK: - Number of Sections

    /// Returns the number of contact sections.
    func numberOfSections(in tableView: UITableView) -> Int {
        @Dependency(\.chatPageViewService.recipientBar?.tableView) var tableViewService: RecipientBarTableViewService?
        return tableViewService?.sections.count ?? 0
    }

    // MARK: - Title for Header in Section

    /// Returns the letter heading the given section.
    func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? {
        @Dependency(\.chatPageViewService.recipientBar?.tableView) var tableViewService: RecipientBarTableViewService?
        return tableViewService?.sections.itemAt(section)?.letter
    }
}
