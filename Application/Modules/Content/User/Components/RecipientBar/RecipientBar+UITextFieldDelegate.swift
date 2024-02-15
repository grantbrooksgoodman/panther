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

extension RecipientBar: UITextFieldDelegate {
    // MARK: - Text Field Should Return

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool { true }
}
