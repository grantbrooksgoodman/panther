//
//  ChatGPTPrompt.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/10/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// A request that asks ChatGPT to reply to the current user's
/// messages in a conversation.
///
/// Create a prompt from a conversation's messages. A prompt that
/// begins a session replies to the messages the current user has sent
/// since ChatGPT's last reply; it also instructs ChatGPT how to reply
/// and includes a transcript of the conversation's most recent
/// messages. A prompt that continues a session replies to the
/// messages the current user has sent that are not yet relayed to the
/// session, and contains only those messages.
struct ChatGPTPrompt {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatGPTPrompt
    private typealias Strings = AppConstants.Strings.ChatGPTPrompt

    // MARK: - Properties

    /// The messages the prompt asks ChatGPT to reply to, sorted by
    /// ascending sent date.
    let messages: [Message]

    /// The prompt's text.
    let text: String

    // MARK: - Init

    /// Creates a prompt that asks ChatGPT to reply to the current
    /// user's messages among the given messages, or returns `nil` if
    /// there are none to reply to.
    ///
    /// Messages without text, such as media messages, are omitted
    /// from the prompt. ChatGPT replies in the current user's language
    /// unless asked otherwise.
    ///
    /// - Parameters:
    ///   - conversationMessages: The conversation's messages.
    ///   - relayedMessageIDs: The identifiers of the messages already
    ///     relayed to the session the prompt continues, or `nil` if
    ///     the prompt begins a session.
    init?(
        conversationMessages: [Message],
        relayedMessageIDs: Set<String>?
    ) {
        @Dependency(\.clientSession.entity.user.currentUser) var currentUser: User?

        let conversationMessages = conversationMessages
            .filter { !$0.isMock && !$0.isOutboxMessage }
            .filter { Self.text(for: $0) != nil }
            .sortedByAscendingSentDate

        let messages = Self.messagesToReplyTo(
            in: conversationMessages,
            relayedMessageIDs: relayedMessageIDs
        )

        guard !messages.isEmpty else { return nil }
        self.messages = messages

        let messagesText = messages
            .compactMap(Self.text(for:))
            .joined(separator: "\n")

        guard relayedMessageIDs == nil else {
            text = messagesText
            return
        }

        let languageCode = currentUser?.languageCode ?? RuntimeStorage.languageCode
        let languageName = Locale(
            identifier: Strings.languageNameLocaleIdentifier
        ).localizedString(
            forLanguageCode: languageCode
        ) ?? languageCode

        var sections = [
            [
                Strings.instructions,
                Strings.languageInstructionPrefix,
                "\(languageName).",
            ].joined(separator: " "),
        ]

        let messageIDs = Set(messages.map(\.id))
        let transcript = conversationMessages
            .filter { !messageIDs.contains($0.id) }
            .suffix(Int(Floats.transcriptMessageCountMaximum))
            .compactMap(Self.transcriptLine(for:))

        if !transcript.isEmpty {
            sections.append(
                ([Strings.transcriptHeader] + transcript)
                    .joined(separator: "\n")
            )
        }

        sections.append(
            [
                Strings.messagesHeader,
                messagesText,
            ].joined(separator: "\n")
        )

        text = sections.joined(separator: "\n\n")
    }

    // MARK: - Auxiliary

    private static func messagesToReplyTo(
        in conversationMessages: [Message],
        relayedMessageIDs: Set<String>?
    ) -> [Message] {
        guard let relayedMessageIDs else {
            let lastReplyIndex = conversationMessages.lastIndex {
                $0.fromAccountID == CommonConstants.chatGPTUserID
            }

            return conversationMessages
                .suffix(from: lastReplyIndex.map { $0 + 1 } ?? 0)
                .filter(\.isFromCurrentUser)
        }

        return conversationMessages.filter {
            $0.isFromCurrentUser &&
                !relayedMessageIDs.contains($0.id)
        }
    }

    private static func text(for message: Message) -> String? {
        guard let text = message
            .translation?
            .input
            .value
            .sanitized
            .trimmingBorderedWhitespace,
            !text.isEmpty else { return nil }
        return text
    }

    private static func transcriptLine(for message: Message) -> String? {
        @Dependency(\.clientSession.store) var sessionStore: SessionStore

        guard let text = text(for: message) else { return nil }

        let label = if message.fromAccountID == CommonConstants.chatGPTUserID {
            Strings.transcriptChatGPTLabel
        } else if message.isFromCurrentUser {
            Strings.transcriptCurrentUserLabel
        } else {
            sessionStore
                .users[message.fromAccountID]?
                .displayName ?? Strings.transcriptParticipantLabel
        }

        return "\(label): \(text)"
    }
}
