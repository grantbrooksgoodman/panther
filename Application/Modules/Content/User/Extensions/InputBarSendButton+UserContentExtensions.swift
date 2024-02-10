//
//  InputBarSendButton+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 03/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import InputBarAccessoryView
import Redux

public extension InputBarSendButton {
    var isRecordButton: Bool {
        @Dependency(\.coreKit.ui) var coreUI: CoreKit.UI
        typealias Strings = AppConstants.Strings.InputBarService

        let imageMatches = image(for: .normal) == .record
        let tagMatches = tag == coreUI.semTag(for: Strings.recordButtonSemanticTag)

        return imageMatches && tagMatches
    }
}
