//
//  RecipientBar+UITableViewDataSource.swift
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

extension RecipientBar: UITableViewDataSource {
    // MARK: - Section Index Titles

    public func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        @Dependency(\.chatPageViewService.recipientBar?.tableView) var tableViewService: RecipientBarTableViewService?
        return tableViewService?.sections.map(\.letter)
    }

    // MARK: - Cell for Row at Index Path

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        @Dependency(\.chatPageViewService.recipientBar?.tableView) var tableViewService: RecipientBarTableViewService?

        typealias Strings = AppConstants.Strings.RecipientBarLayoutService
        let cell = tableView.dequeueReusableCell(withIdentifier: Strings.tableViewCellReuseIdentifier, for: indexPath)

        guard let tableViewService,
              tableViewService.sections.count > indexPath.row else { return cell }

        cell.textLabel?.text = tableViewService.sections[indexPath.row].contactPairs.first?.contact.fullName

        return cell
    }

    // MARK: - Number of Rows in Section

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        @Dependency(\.chatPageViewService.recipientBar?.tableView) var tableViewService: RecipientBarTableViewService?
        return tableViewService?.sections.count ?? 0
    }

    // MARK: - Title for Header in Section

    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        @Dependency(\.chatPageViewService.recipientBar?.tableView) var tableViewService: RecipientBarTableViewService?
        guard let tableViewService,
              tableViewService.sections.count > section else { return nil }
        return tableViewService.sections[section].letter
    }
}
