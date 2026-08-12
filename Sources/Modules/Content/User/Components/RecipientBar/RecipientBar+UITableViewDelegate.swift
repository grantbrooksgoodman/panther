//
//  RecipientBar+UITableViewDelegate.swift
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

extension RecipientBar: UITableViewDelegate {
    // MARK: - Did Select Row

    /// Selects the contact pair at the given index path and gives the text field focus if it
    /// does not already have it.
    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        @Dependency(\.chatPageViewService.recipientBar) var recipientBarService: RecipientBarService?
        guard let contactPair = recipientBarService?.tableView.sections.itemAt(indexPath.section)?.contactPairs.itemAt(indexPath.row) else { return }
        recipientBarService?.contactSelectionUI.selectContactPair(contactPair)
        guard recipientBarService?.layout.textField?.isFirstResponder == false else { return }
        recipientBarService?.layout.textField?.becomeFirstResponder()
    }

    // MARK: - Scroll View Did Scroll

    /// Dismisses the keyboard when the user scrolls the contact list.
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        @Dependency(\.chatPageViewService.recipientBar?.layout) var layoutService: RecipientBarLayoutService?
        guard let textField = layoutService?.textField,
              textField.isFirstResponder else { return }
        textField.resignFirstResponder()
    }
}
