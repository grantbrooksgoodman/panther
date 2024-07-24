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
import CoreArchitecture
import MessageKit

extension ChatPageViewController: UITextViewDelegate {
    // MARK: - Properties

    override public var textInputMode: UITextInputMode? {
        .activeInputModes
            .filter { $0.primaryLanguage != nil }
            .first(where: { $0.primaryLanguage!.lowercased().hasPrefix(RuntimeStorage.languageCode) })
    }

    // MARK: - Should Begin Editing

    public func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        @Dependency(\.chatPageViewService) var chatPageViewService: ChatPageViewService
        @Dependency(\.coreKit.gcd) var coreGCD: CoreKit.GCD

        guard let inputBarService = chatPageViewService.inputBar,
              let recipientBarService = chatPageViewService.recipientBar,
              let textField = recipientBarService.layout.textField else { return true }

        guard recipientBarService.contactSelectionUI.selectedContactPairs.contains(where: { $0.isMock }) || textField.isFirstResponder,
              recipientBarService.layout.tableView?.alpha == 0 else { return true }

        recipientBarService.actionHandler.textFieldShouldReturn(textField.text ?? "", makeInputBarFirstResponder: false)
        typealias Floats = AppConstants.CGFloats.ChatPageView.UITextViewDelegate
        coreGCD.after(.milliseconds(Floats.setButtonsIsEnabledDelayMilliseconds)) {
            inputBarService.setAttachMediaButtonIsEnabled(inputBarService.shouldEnableAttachMediaButton)
            inputBarService.setSendButtonIsEnabled(inputBarService.shouldEnableSendButton)
        }

        return true
    }

    // MARK: - Did Begin Editing

    public func textViewDidBeginEditing(_ textView: UITextView) {
        @Dependency(\.chatPageViewService) var chatPageViewService: ChatPageViewService
        @Dependency(\.coreKit.gcd) var coreGCD: CoreKit.GCD

        typealias Floats = AppConstants.CGFloats.ChatPageView.UITextViewDelegate
        coreGCD.after(.milliseconds(Floats.toggleLabelRepresentationDelayMilliseconds)) {
            chatPageViewService.recipientBar?.contactSelectionUI.toggleLabelRepresentation(on: true)
        }

        guard let inputBarService = chatPageViewService.inputBar else { return }
        inputBarService.setAttachMediaButtonIsEnabled(inputBarService.shouldEnableAttachMediaButton)
        inputBarService.setSendButtonIsEnabled(inputBarService.shouldEnableSendButton)
    }

    // MARK: - Should Change Text in Range

    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        @Dependency(\.commonServices.audio.recording) var recordingService: RecordingService
        return !recordingService.isInOrWillTransitionToRecordingState
    }

    // MARK: - Did Change

    public func textViewDidChange(_ textView: UITextView) {
        @Dependency(\.chatPageViewService.inputBar) var inputBarService: InputBarService?
        inputBarService?.configureInputBar()
    }
}
