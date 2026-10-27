//
//  Message+ChatGPTExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 27/10/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension Message {
    // MARK: - Type Aliases

    private typealias Strings = AppConstants.Strings.ChatGPTPrompt

    // MARK: - Properties

    /// A Boolean value that indicates whether the message was sent
    /// by ChatGPT.
    var isFromChatGPT: Bool {
        fromAccountID == CommonConstants.chatGPTUserID
    }

    /// A Boolean value that indicates whether the message is
    /// undelivered to ChatGPT because ChatGPT failed to reply to it.
    ///
    /// Only the current user's messages are undelivered to ChatGPT.
    @MainActor
    var isUndeliveredToChatGPT: Bool {
        @Dependency(\.commonServices.chatGPT) var chatGPTService: ChatGPTService
        guard isFromCurrentUser else { return false }
        return chatGPTService.isUndelivered(self)
    }

    /// A Boolean value that indicates whether the message's text
    /// mentions ChatGPT.
    var mentionsChatGPT: Bool {
        translation?
            .input
            .value
            .range(
                of: Strings.mentionToken,
                options: .caseInsensitive
            ) != nil
    }
}
