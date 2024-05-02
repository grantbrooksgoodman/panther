//
//  ConversationCellViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import AlertKit
import Redux

public final class ConversationCellViewService {
    /// `.deleteConversationButtonTapped`
    /// - Returns: `true` if the user selected the cancel option.
    public func presentDeletionActionSheet(_ title: String) async -> Bool {
        let actionSheet: AKActionSheet = .init(
            title: title,
            message: "Are you sure you'd like to delete this conversation?\nThis operation cannot be undone.",
            actions: [.init(title: "Delete", style: .destructive)],
            shouldTranslate: [.actions(indices: nil), .message],
            networkDependent: true
        )

        let actionID = await actionSheet.present()
        return actionID == -1
    }
}
