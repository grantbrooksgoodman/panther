//
//  ChatPageViewController+UITextViewDelegate.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 31/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import MessageKit
import Redux

extension ChatPageViewController: UITextViewDelegate {
    // MARK: - Properties

    override public var textInputMode: UITextInputMode? {
        .activeInputModes
            .filter { $0.primaryLanguage != nil }
            .first(where: { $0.primaryLanguage!.lowercased().hasPrefix(RuntimeStorage.languageCode) })
    }

    // MARK: - Methods

    public func textViewDidBeginEditing(_ textView: UITextView) {}

    public func textViewDidChange(_ textView: UITextView) {
        @Dependency(\.chatPageViewService.inputBar) var inputBarService: InputBarService?
        inputBarService?.configureInputBar()
    }
}
