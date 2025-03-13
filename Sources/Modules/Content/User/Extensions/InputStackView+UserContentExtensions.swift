//
//  InputStackView+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 13/07/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import InputBarAccessoryView

public extension InputStackView {
    var attachMediaButton: UIButton? {
        typealias Strings = AppConstants.Strings.ChatPageViewService.InputBar
        return firstSubview(for: Strings.attachMediaButtonSemanticTag) as? UIButton
    }
}
