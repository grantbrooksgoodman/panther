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
        static let transcriptMessageCountMaximum: CGFloat = 20
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum ChatGPTPrompt {
        // swiftlint:disable:next line_length
        static let instructions = "You are ChatGPT, messaging with a person through Panther, a messaging app. Write each reply as a text message: conversational, concise, and in plain text without Markdown formatting."
        static let languageInstructionPrefix = "Unless the person asks otherwise, reply in"
        static let languageNameLocaleIdentifier = "en"
        static let messagesHeader = "Reply to the following:"

        static let transcriptChatGPTLabel = "You"
        static let transcriptCurrentUserLabel = "Person"
        static let transcriptHeader = "The conversation so far:"
        static let transcriptParticipantLabel = "Participant"
    }
}
