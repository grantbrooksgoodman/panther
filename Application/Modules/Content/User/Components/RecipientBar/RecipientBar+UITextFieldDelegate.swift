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
import Redux

extension RecipientBar: UITextFieldDelegate {
    // MARK: - Should Return

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        @Dependency(\.chatPageViewService.recipientBar?.contactSelectionUI) var contactSelectionUIService: RecipientBarContactSelectionUIService?
        contactSelectionUIService?.textFieldShouldReturn(textField.text ?? "")
        return true
    }
}
