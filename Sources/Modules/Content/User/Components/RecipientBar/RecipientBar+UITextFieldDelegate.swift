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

    /// Halts any in-flight scrolling of the contact list, then allows editing to begin.
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        @Dependency(\.chatPageViewService.recipientBar?.layout.tableView) var recipientBarTableView: UITableView?
        guard let recipientBarTableView else { return true }
        recipientBarTableView.setContentOffset(recipientBarTableView.contentOffset, animated: false)
        return true
    }

    // MARK: - Should Return

    /// Forwards the entered text to the recipient bar's action handler.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        @Dependency(\.chatPageViewService.recipientBar?.actionHandler) var actionHandlerService: RecipientBarActionHandlerService?
        actionHandlerService?.textFieldShouldReturn(textField.text ?? "")
        return true
    }

    // MARK: - Did Begin Editing

    /// Disables the input bar's attach media and send buttons and, unless the input bar is
    /// forcing its appearance, switches the contact selection UI out of its label
    /// representation.
    func textFieldDidBeginEditing(_ textField: UITextField) {
        @Dependency(\.chatPageViewService) var chatPageViewService: ChatPageViewService
        chatPageViewService.inputBar?.setAttachMediaButtonIsEnabled(false)
        chatPageViewService.inputBar?.setSendButtonIsEnabled(false)
        guard chatPageViewService.inputBar?.isForcingAppearance == false else { return }
        chatPageViewService.recipientBar?.contactSelectionUI.toggleLabelRepresentation(on: false)
    }

    // MARK: - Did End Editing

    /// After a short delay, restores the contact selection UI's label representation, unless
    /// the input bar has focus or is forcing its appearance.
    func textFieldDidEndEditing(_ textField: UITextField) {
        @Dependency(\.chatPageViewService) var chatPageViewService: ChatPageViewService
        typealias Floats = AppConstants
            .CGFloats
            .ChatPageViewService
            .RecipientBarService
            .UITextFieldDelegate

        Task.delayed(by: .milliseconds(
            Floats.toggleLabelRepresentationDelayMilliseconds
        )) { @MainActor in
            guard chatPageViewService.inputBar?.isFirstResponder == false,
                  chatPageViewService.inputBar?.isForcingAppearance == false else { return }
            chatPageViewService
                .recipientBar?
                .contactSelectionUI
                .toggleLabelRepresentation(on: true)
        }
    }
}
