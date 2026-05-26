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

extension ChatPageViewController: @MainActor InputBarAccessoryViewDelegate {
    // MARK: - Did Press Send Button

    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        @Dependency(\.chatPageViewService.inputBar) var inputBarService: InputBarService?
        Task {
            do throws(Exception) {
                try await inputBarService?.actionHandler.didPressSendButton(
                    with: text
                )
            } catch {
                Logger.log(
                    error,
                    with: .toast
                )
            }
        }
    }

    // MARK: - Text View Did Change

    func inputBar(_ inputBar: InputBarAccessoryView, textViewTextDidChangeTo text: String) {
        @Dependency(\.chatPageViewService.typingIndicator) var typingIndicatorService: TypingIndicatorService?
        Task.background { @MainActor in
            do throws(Exception) {
                try await typingIndicatorService?.textViewDidChange(
                    to: text
                )
            } catch {
                Logger.log(error)
            }
        }
    }
}
