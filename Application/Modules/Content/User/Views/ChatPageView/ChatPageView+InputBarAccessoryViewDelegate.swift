//
//  ChatPageView+InputBarAccessoryViewDelegate.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 31/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import InputBarAccessoryView
import Redux

extension ChatPageViewController: InputBarAccessoryViewDelegate {
    // MARK: - Did Press Send Button

    public func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {}

    // MARK: - Text View Did Change

    public func inputBar(_ inputBar: InputBarAccessoryView, textViewTextDidChangeTo text: String) {}
}
