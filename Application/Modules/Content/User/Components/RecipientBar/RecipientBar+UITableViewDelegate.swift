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

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        @Dependency(\.chatPageViewService.recipientBar) var recipientBarService: RecipientBarService?
        guard let contactPair = recipientBarService?.tableView.sections.itemAt(indexPath.section)?.contactPairs.itemAt(indexPath.row) else { return }
        recipientBarService?.contactSelectionUI.selectContactPair(contactPair)
    }

    // MARK: - Scroll View Did Scroll

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        @Dependency(\.chatPageViewService.recipientBar?.layout) var layoutService: RecipientBarLayoutService?
        guard let textField = layoutService?.textField,
              textField.isFirstResponder else { return }
        textField.resignFirstResponder()
    }
}
