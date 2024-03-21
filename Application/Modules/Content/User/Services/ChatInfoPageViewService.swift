//
//  ChatInfoPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import AlertKit
import Redux

public struct ChatInfoPageViewService {
    // MARK: - Dependencies

    @Dependency(\.clientSession.conversation.currentConversation) private var currentConversation: Conversation?

    // MARK: - Methods

    public func presentChangeNameAlert() async -> String? {
        var conversationName = ""
        if let name = currentConversation?.name,
           !name.isBangQualifiedEmpty {
            conversationName = name
        }

        let alert: AKTextFieldAlert = .init(
            message: "Choose a new name for this conversation:",
            actions: [.init(title: "Done", style: .preferred)],
            textFieldAttributes: [
                .editingMode: UITextField.ViewMode.always,
                .sampleText: conversationName,
            ],
            networkDependent: true
        )

        let presentTextFieldAlertResult = await alert.presentTextFieldAlert()
        guard presentTextFieldAlertResult.actionID != -1 else { return nil }
        return presentTextFieldAlertResult.input
    }
}
