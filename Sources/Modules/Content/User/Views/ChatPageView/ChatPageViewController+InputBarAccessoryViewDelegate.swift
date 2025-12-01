//
//  ChatPageViewController+InputBarAccessoryViewDelegate.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 31/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import InputBarAccessoryView

extension ChatPageViewController: InputBarAccessoryViewDelegate {
    // MARK: - Did Press Send Button

    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        @Dependency(\.chatPageViewService.inputBar) var inputBarService: InputBarService?
        Task {
            if let exception = await inputBarService?.actionHandler.didPressSendButton(with: text) {
                Logger.log(exception, with: .toast)
            }
        }
    }

    // MARK: - Text View Did Change

    func inputBar(_ inputBar: InputBarAccessoryView, textViewTextDidChangeTo text: String) {
        @Dependency(\.chatPageViewService.typingIndicator) var typingIndicatorService: TypingIndicatorService?
        Task.background {
            if let exception = await typingIndicatorService?.textViewDidChange(to: text) {
                Logger.log(exception)
            }
        }
    }
}
