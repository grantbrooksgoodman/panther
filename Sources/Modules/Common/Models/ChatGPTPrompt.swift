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

/// A request that asks ChatGPT to reply to the latest messages in a
/// conversation.
///
/// Create a prompt from a conversation. A prompt that begins a session
/// replies to the messages sent since ChatGPT's last reply; it also
/// instructs ChatGPT how to reply, names the conversation's
/// participants, and includes a transcript of the conversation's most
/// recent messages. A prompt that continues a session replies to the
/// messages not yet relayed to the session, and contains only those
/// messages. Every message is attributed to its sender by name.
///
/// ChatGPT may answer a prompt with several consecutive messages, as
/// a person texting would; ``replies(from:)`` separates them. In a
/// group conversation, ChatGPT is instructed to reply only when a
/// message addresses it directly or the conversation clearly calls
/// for its reply; ``allowsNoReply`` is `true` for such a prompt.
struct ChatGPTPrompt {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatGPTPrompt
    private typealias Strings = AppConstants.Strings.ChatGPTPrompt

    // MARK: - Properties

    /// A Boolean value that indicates whether ChatGPT may decline to
    /// reply to the prompt.
    let allowsNoReply: Bool

    /// The messages the prompt asks ChatGPT to reply to, sorted by
    /// ascending sent date.
    let messages: [Message]

    /// The prompt's text.
    let text: String

    // MARK: - Init

    /// Creates a prompt that asks ChatGPT to reply to the latest
    /// messages in the given conversation, or returns `nil` if there
    /// are none to reply to.
    ///
    /// Messages without text, such as media messages, are omitted
    /// from the prompt. ChatGPT replies in the current user's language
    /// unless asked otherwise.
    ///
    /// - Parameters:
    ///   - conversation: The conversation to reply in.
    ///   - relayedMessageIDs: The identifiers of the messages already
    ///     relayed to the session the prompt continues, or `nil` if
    ///     the prompt begins a session.
    init?(
        conversation: Conversation,
        relayedMessageIDs: Set<String>?
    ) {
        @Dependency(\.clientSession.entity.user.currentUser) var currentUser: User?

        let conversationMessages = (conversation.messages ?? [])
            .filter { !$0.isMock && !$0.isOutboxMessage }
            .filter { Self.text(for: $0) != nil }
            .sortedByAscendingSentDate

        let messages = Self.messagesToReplyTo(
            in: conversationMessages,
            relayedMessageIDs: relayedMessageIDs
        )

        guard !messages.isEmpty else { return nil }
        self.messages = messages
        allowsNoReply = conversation.participants.count >= Int(Floats.groupConversationParticipantCountMinimum)

        let messagesText = messages
            .compactMap(Self.transcriptLine(for:))
            .joined(separator: "\n")

        guard relayedMessageIDs == nil else {
            text = messagesText
            return
        }

        var sections = [
            Self.instructions(
                for: conversation,
                currentUser: currentUser,
                allowsNoReply: allowsNoReply
            ),
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

    // MARK: - Methods

    /// Returns ChatGPT's replies from the given response to the
    /// prompt, in the order to send them.
    ///
    /// - Parameter response: ChatGPT's response to the prompt.
    ///
    /// - Returns: The replies, or an empty array if ChatGPT declined
    ///   to reply.
    func replies(from response: String) -> [String] {
        response
            .components(separatedBy: "\n")
            .split(whereSeparator: { Self.isToken($0, Strings.messageSeparatorToken) })
            .map { $0.joined(separator: "\n").trimmingBorderedWhitespace }
            .filter { !$0.isEmpty && !Self.isToken($0, Strings.noReplyToken) }
    }

    // MARK: - Auxiliary

    private static func isToken(
        _ line: String,
        _ token: String
    ) -> Bool {
        line
            .removingOccurrences(of: ["\"", "“", "”", "`", "*"])
            .trimmingBorderedWhitespace
            .uppercased() == token
    }

    private static func instructions(
        for conversation: Conversation,
        currentUser: User?,
        allowsNoReply: Bool
    ) -> String {
        let languageCode = currentUser?.languageCode ?? RuntimeStorage.languageCode
        let languageName = Locale(
            identifier: Strings.languageNameLocaleIdentifier
        ).localizedString(
            forLanguageCode: languageCode
        ) ?? languageCode

        var participantNames = (conversation.users ?? [])
            .filter { !$0.isChatGPT }
            .map(\.displayName)

        if let currentUser {
            participantNames.insert(
                currentUser.displayName,
                at: 0
            )
        }

        var sentences = [
            Strings.instructions,
            "\(Strings.languageInstructionPrefix) \(languageName).",
        ]

        if !participantNames.isEmpty {
            sentences.append(
                "\(Strings.participantsInstructionPrefix) \(participantNames.joined(separator: ", "))."
            )
        }

        if allowsNoReply {
            sentences.append(Strings.groupConversationInstructions)
        }

        return sentences.joined(separator: " ")
    }

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
                .filter { $0.fromAccountID != CommonConstants.chatGPTUserID }
        }

        return conversationMessages.filter {
            $0.fromAccountID != CommonConstants.chatGPTUserID &&
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
        @Dependency(\.clientSession.entity.user.currentUser) var currentUser: User?
        @Dependency(\.clientSession.store) var sessionStore: SessionStore

        guard let text = text(for: message) else { return nil }

        let label = if message.fromAccountID == CommonConstants.chatGPTUserID {
            Strings.transcriptChatGPTLabel
        } else if message.isFromCurrentUser,
                  let currentUser {
            currentUser.displayName
        } else {
            sessionStore
                .users[message.fromAccountID]?
                .displayName ?? Strings.transcriptParticipantLabel
        }

        return "\(label): \(text)"
    }
}
