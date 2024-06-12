//
//  ChatPageViewController+InputBarAccessoryViewDelegate.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 31/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture
import InputBarAccessoryView

extension ChatPageViewController: InputBarAccessoryViewDelegate {
    // MARK: - Did Press Send Button

    public func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        @Dependency(\.chatPageViewService.inputBar) var inputBarService: InputBarService?
        Task {
            if let exception = await inputBarService?.didPressSendButton(with: text) {
                Logger.log(exception, with: .toast())
            }
        }
    }

    // MARK: - Text View Did Change

    public func inputBar(_ inputBar: InputBarAccessoryView, textViewTextDidChangeTo text: String) {
        @Dependency(\.chatPageViewService.inputBar) var inputBarService: InputBarService?
        Task {
            if let exception = await inputBarService?.textViewDidChange(to: text) {
                Logger.log(exception, with: .toast())
            }
        }
    }
}
