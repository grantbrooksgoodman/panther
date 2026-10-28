//
//  AppConstants+ChatGPTPrompt.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/10/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum ChatGPTPrompt {
        static let groupConversationParticipantCountMinimum: CGFloat = 3
        static let transcriptMessageCountMaximum: CGFloat = 20
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum ChatGPTPrompt {
        // swiftlint:disable line_length
        static let groupConversationInstructions = "This is a group conversation. Reply only to the messages that mention you with \(mentionToken); the other messages are provided for context."
        static let instructions = "You are ChatGPT, messaging through Hello, a messaging app. Write each reply as a text message: conversational, concise, and in plain text without Markdown formatting. Each message is prefixed with its sender's name; do not prefix your replies. You may reply with several messages in a row, as a person texting would; separate consecutive messages with a line containing only \(messageSeparatorToken). Do not include citations, source names, or links."
        // swiftlint:enable line_length
        static let languageInstructionPrefix = "Unless asked otherwise, reply in"
        static let languageNameLocaleIdentifier = "en"
        static let mentionToken = "@chat"
        static let messageSeparatorPattern = #"["“”`*]*\[\s*NEXT\s+MESSAGE\s*\]["“”`*]*"#
        static let messageSeparatorToken = "[NEXT MESSAGE]"
        static let messagesHeader = "Reply to the following:"
        static let participantsInstructionPrefix = "You are in a conversation with"

        static let transcriptChatGPTLabel = "You"
        static let transcriptHeader = "The conversation so far:"
        static let transcriptParticipantLabel = "Participant"
    }
}
