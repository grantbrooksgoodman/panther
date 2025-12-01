//
//  RecipientBar+UITextFieldDelegate.swift
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

extension RecipientBar: UITextFieldDelegate {
    // MARK: - Should Begin Editing

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        @Dependency(\.chatPageViewService.recipientBar?.layout.tableView) var recipientBarTableView: UITableView?
        guard let recipientBarTableView else { return true }
        recipientBarTableView.setContentOffset(recipientBarTableView.contentOffset, animated: false)
        return true
    }

    // MARK: - Should Return

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        @Dependency(\.chatPageViewService.recipientBar?.actionHandler) var actionHandlerService: RecipientBarActionHandlerService?
        actionHandlerService?.textFieldShouldReturn(textField.text ?? "")
        return true
    }

    // MARK: - Did Begin Editing

    func textFieldDidBeginEditing(_ textField: UITextField) {
        @Dependency(\.chatPageViewService) var chatPageViewService: ChatPageViewService
        chatPageViewService.inputBar?.setAttachMediaButtonIsEnabled(false)
        chatPageViewService.inputBar?.setSendButtonIsEnabled(false)
        guard chatPageViewService.inputBar?.isForcingAppearance == false else { return }
        chatPageViewService.recipientBar?.contactSelectionUI.toggleLabelRepresentation(on: false)
    }

    // MARK: - Did End Editing

    func textFieldDidEndEditing(_ textField: UITextField) {
        @Dependency(\.chatPageViewService) var chatPageViewService: ChatPageViewService
        @Dependency(\.coreKit.gcd) var coreGCD: CoreKit.GCD
        typealias Floats = AppConstants.CGFloats.ChatPageViewService.RecipientBarService.UITextFieldDelegate
        coreGCD.after(.milliseconds(Floats.toggleLabelRepresentationDelayMilliseconds)) {
            guard chatPageViewService.inputBar?.isFirstResponder == false,
                  chatPageViewService.inputBar?.isForcingAppearance == false else { return }
            chatPageViewService.recipientBar?.contactSelectionUI.toggleLabelRepresentation(on: true)
        }
    }
}
