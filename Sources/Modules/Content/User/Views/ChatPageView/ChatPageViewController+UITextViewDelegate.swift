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

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import MessageKit

extension ChatPageViewController: UITextViewDelegate {
    // MARK: - Properties

    override var textInputMode: UITextInputMode? {
        .activeInputModes
            .filter { $0.primaryLanguage != nil }
            .first(where: { $0.primaryLanguage!.lowercased().hasPrefix(RuntimeStorage.languageCode) })
    }

    // MARK: - Should Begin Editing

    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        @Dependency(\.chatPageViewService) var chatPageViewService: ChatPageViewService

        guard let recipientBarService = chatPageViewService.recipientBar,
              let textField = recipientBarService.layout.textField else { return true }

        guard recipientBarService.contactSelectionUI.selectedContactPairs.contains(where: \.isMock) || textField.isFirstResponder,
              recipientBarService.layout.tableView?.alpha == 0 else { return true }

        recipientBarService.actionHandler.textFieldShouldReturn(textField.text ?? "", makeInputBarFirstResponder: false)
        return true
    }

    // MARK: - Did Begin Editing

    func textViewDidBeginEditing(_ textView: UITextView) {
        @Dependency(\.chatPageViewService) var chatPageViewService: ChatPageViewService
        @Dependency(\.coreKit.gcd) var coreGCD: CoreKit.GCD

        typealias Floats = AppConstants.CGFloats.ChatPageView.UITextViewDelegate
        coreGCD.after(.milliseconds(Floats.toggleLabelRepresentationDelayMilliseconds)) {
            guard chatPageViewService.inputBar?.isForcingAppearance == false else { return }
            chatPageViewService.recipientBar?.contactSelectionUI.toggleLabelRepresentation(on: true)
        }

        guard let inputBarService = chatPageViewService.inputBar else { return }
        inputBarService.setAttachMediaButtonIsEnabled(inputBarService.shouldEnableAttachMediaButton)
        inputBarService.setSendButtonIsEnabled(inputBarService.shouldEnableSendButton)
    }

    // MARK: - Should Change Text in Range

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        @Dependency(\.commonServices.audio.recording) var recordingService: RecordingService
        return !recordingService.isInOrWillTransitionToRecordingState
    }

    // MARK: - Did Change

    func textViewDidChange(_ textView: UITextView) {
        @Dependency(\.chatPageViewService.inputBar) var inputBarService: InputBarService?
        inputBarService?.configureInputBar()
    }
}
