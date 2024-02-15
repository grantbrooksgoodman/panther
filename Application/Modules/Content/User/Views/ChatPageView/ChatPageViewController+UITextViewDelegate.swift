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

    // MARK: - Should Change Text in Range

    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        @Dependency(\.commonServices.audio.recording) var recordingService: RecordingService
        return !recordingService.isInOrWillTransitionToRecordingState
    }

    // MARK: - Did Begin Editing

    public func textViewDidBeginEditing(_ textView: UITextView) {
        @Dependency(\.chatPageViewService.recipientBar?.contactSelectionUI) var contactSelectionUIService: RecipientBarContactSelectionUIService?
        contactSelectionUIService?.unhighlightAllViews()
    }

    // MARK: - Did Change

    public func textViewDidChange(_ textView: UITextView) {
        @Dependency(\.chatPageViewService.inputBar) var inputBarService: InputBarService?
        inputBarService?.configureInputBar()
    }
}
