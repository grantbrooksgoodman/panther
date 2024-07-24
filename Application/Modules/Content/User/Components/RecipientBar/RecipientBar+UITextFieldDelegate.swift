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

/* 3rd-party */
import CoreArchitecture

extension RecipientBar: UITextFieldDelegate {
    // MARK: - Should Begin Editing

    public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        @Dependency(\.chatPageViewService.recipientBar?.layout.tableView) var recipientBarTableView: UITableView?
        guard let recipientBarTableView else { return true }
        recipientBarTableView.setContentOffset(recipientBarTableView.contentOffset, animated: false)
        return true
    }

    // MARK: - Should Return

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        @Dependency(\.chatPageViewService.recipientBar?.actionHandler) var actionHandlerService: RecipientBarActionHandlerService?
        actionHandlerService?.textFieldShouldReturn(textField.text ?? "")
        return true
    }

    // MARK: - Did Begin Editing

    public func textFieldDidBeginEditing(_ textField: UITextField) {
        @Dependency(\.chatPageViewService) var chatPageViewService: ChatPageViewService
        chatPageViewService.inputBar?.setAttachMediaButtonIsEnabled(false)
        chatPageViewService.inputBar?.setSendButtonIsEnabled(false)
        chatPageViewService.recipientBar?.contactSelectionUI.toggleLabelRepresentation(on: false)
    }

    // MARK: - Did End Editing

    public func textFieldDidEndEditing(_ textField: UITextField) {
        @Dependency(\.chatPageViewService.recipientBar?.contactSelectionUI) var contactSelectionUIService: RecipientBarContactSelectionUIService?
        @Dependency(\.coreKit.gcd) var coreGCD: CoreKit.GCD
        typealias Floats = AppConstants.CGFloats.ChatPageViewService.RecipientBarService.UITextFieldDelegate
        coreGCD.after(.milliseconds(Floats.toggleLabelRepresentationDelayMilliseconds)) { contactSelectionUIService?.toggleLabelRepresentation(on: true) }
    }
}
