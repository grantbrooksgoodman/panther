//
//  ChatGPTService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/10/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import LanguageModels
import Networking

/// The service that makes ChatGPT available as a conversation
/// participant.
///
/// Use ``ChatGPTService`` to add ChatGPT as a recipient, and to have
/// it reply to the messages the current user sends it. ChatGPT is
/// represented by a registered user account, so a conversation with
/// ChatGPT is stored, synchronized, and displayed like any other.
/// ChatGPT marks the messages it answers as read and sends each reply
/// from its account as an ordinary text message – or as several
/// consecutive messages, as a person texting would. As with any
/// participant, it appears as typing while it composes a reply only in
/// a one-to-one conversation. In a group conversation, ChatGPT
/// receives and replies to only the messages that mention it with
/// `@chat`.
///
/// A prompt that fails to submit is resubmitted automatically. When
/// ChatGPT still fails to reply – or the app terminates while it is
/// replying – the messages it was answering are undelivered to ChatGPT
/// until delivery is retried with ``retryDelivery(in:)``, or until
/// another message prompts a reply. Undelivered messages persist
/// across launches.
///
/// The service keeps one ChatGPT session per conversation in memory,
/// so each reply continues the same session. A conversation begins a
/// new session with its first reply after launch, or after a reply
/// fails; the first reply in a new session is primed with the
/// conversation's most recent messages.
///
/// - Important: The service is main-actor isolated.
@MainActor
final class ChatGPTService {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatGPTService
    private typealias Strings = AppConstants.Strings.ChatGPTService

    // MARK: - Types

    private struct ConversationContext {
        let relayedMessageIDs: Set<String>
        let session: LanguageModelSession
    }

    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Properties

    private let replyCoalescer = Coalescer<String, Void, Never>(policy: .rerun)

    private var conversationContexts = [String: ConversationContext]()
    @Persistent(.inFlightReplyMessageIDs) private var inFlightReplyMessageIDs: [String: [String]]?
    @Persistent(.undeliveredMessageIDs) private var persistedUndeliveredMessageIDs: Set<String>?
    private var preparedSession: LanguageModelSession?
    private var undeliveredMessageIDs = Set<String>() {
        didSet { persistUndeliveredMessageIDs() }
    }

    // MARK: - Init

    init() {
        undeliveredMessageIDs = persistedUndeliveredMessageIDs ?? []
        recoverInterruptedReplies()
    }

    // MARK: - Methods

    /// Returns a Boolean value that indicates whether the given
    /// recipient bar text selects ChatGPT as a recipient.
    ///
    /// - Parameter text: The text entered in the recipient bar.
    ///
    /// - Returns: `true` if the text selects ChatGPT; otherwise,
    ///   `false`.
    func isRecipientQuery(_ text: String) -> Bool {
        Strings.recipientQueries.contains(
            text.trimmingBorderedWhitespace
        )
    }

    /// Returns a Boolean value that indicates whether the given
    /// message is undelivered to ChatGPT.
    ///
    /// A message is undelivered to ChatGPT when ChatGPT failed to
    /// reply to it.
    ///
    /// - Parameter message: The message to check.
    ///
    /// - Returns: `true` if the message is undelivered to ChatGPT;
    ///   otherwise, `false`.
    func isUndelivered(_ message: Message) -> Bool {
        undeliveredMessageIDs.contains(message.id)
    }

    /// Loads ChatGPT ahead of the first reply in a new session.
    ///
    /// Call this method once a reply from ChatGPT is imminent – for
    /// example, when the user selects ChatGPT as a recipient – to
    /// reduce the latency of that reply. The next conversation that
    /// begins a session uses the loaded session. Calling this method
    /// again before then has no effect.
    func prewarm() {
        guard preparedSession == nil else { return }

        let session = LanguageModelSession(.chatGPT)
        session.prewarm()
        preparedSession = session
    }

    /// Requests a reply from ChatGPT to the messages the current user
    /// has sent in the given conversation.
    ///
    /// Call this method after the current user sends a message. When
    /// the message is from the current user and ChatGPT participates
    /// in the conversation, ChatGPT replies to the messages sent since
    /// its last reply – including any that are undelivered to ChatGPT.
    /// In a group conversation, only messages that mention ChatGPT
    /// with `@chat` are relayed. Otherwise, this method does nothing.
    ///
    /// Replies to a conversation are composed one at a time. A request
    /// made while a reply is being composed is fulfilled once that
    /// reply is sent, so ChatGPT replies to each message once.
    ///
    /// - Parameters:
    ///   - message: The message the current user sent.
    ///   - conversation: The conversation the message was sent in.
    func requestReply(
        to message: Message,
        in conversation: Conversation
    ) {
        guard message.isFromCurrentUser,
              conversation
              .participants
              .contains(where: { $0.userID == CommonConstants.chatGPTUserID }) else { return }

        enqueueReply(in: conversation)
    }

    /// Discards the service's sessions and delivery records.
    func reset() {
        conversationContexts = [:]
        inFlightReplyMessageIDs = nil
        preparedSession = nil
        undeliveredMessageIDs = []
    }

    /// Returns the contact pair that represents ChatGPT, creating
    /// ChatGPT's user account if it does not exist.
    ///
    /// ChatGPT's user account is upserted into the session store, so
    /// the users of the returned contact pair resolve.
    ///
    /// - Returns: The contact pair that represents ChatGPT.
    ///
    /// - Throws: An `Exception` if ChatGPT's user account cannot be
    ///   fetched or created.
    func resolveContactPair() async throws(Exception) -> ContactPair {
        try await .chatGPT(resolveUser())
    }

    /// Retries delivering the messages in the given conversation that
    /// are undelivered to ChatGPT.
    ///
    /// The messages are not sent again; instead, ChatGPT is prompted
    /// with them once more. They are no longer undelivered while
    /// ChatGPT replies, and become undelivered again if the reply
    /// fails.
    ///
    /// - Parameter conversation: The conversation whose undelivered
    ///   messages to retry.
    func retryDelivery(in conversation: Conversation) {
        setIsUndelivered(
            false,
            messageIDs: conversation.messageIDs,
            in: conversation
        )

        enqueueReply(in: conversation)
    }

    // MARK: - Auxiliary

    private func enqueueReply(in conversation: Conversation) {
        Task {
            await replyCoalescer(conversation.id.key) { [weak self] in
                await self?.reply(in: conversation)
            }
        }
    }

    private func latestVersion(
        of conversation: Conversation
    ) -> Conversation {
        clientSession.store.getConversation(
            idKey: conversation.id.key
        ) ?? conversation
    }

    private func persistUndeliveredMessageIDs() {
        guard !undeliveredMessageIDs.isEmpty else {
            return persistedUndeliveredMessageIDs = nil
        }

        persistedUndeliveredMessageIDs = undeliveredMessageIDs
    }

    /// A reply interrupted by termination leaves its messages
    /// unanswered and ChatGPT marked as typing; the messages become
    /// undelivered and the typing status is cleared.
    private func recoverInterruptedReplies() {
        guard let inFlightReplyMessageIDs,
              !inFlightReplyMessageIDs.isEmpty else { return }

        self.inFlightReplyMessageIDs = nil
        undeliveredMessageIDs.formUnion(
            inFlightReplyMessageIDs.values.flatMap(\.self)
        )

        Task {
            for conversationIDKey in inFlightReplyMessageIDs.keys {
                await setIsTyping(
                    false,
                    inConversationWithIDKey: conversationIDKey
                )
            }
        }
    }

    private func reply(in conversation: Conversation) async {
        let conversation = latestVersion(of: conversation)
        let context = conversationContexts[conversation.id.key]
        guard let prompt = ChatGPTPrompt(
            conversation: conversation,
            relayedMessageIDs: context?.relayedMessageIDs
        ) else { return }

        let messageIDs = prompt.messages.filter(\.isFromCurrentUser).map(\.id)
        setIsUndelivered(
            false,
            messageIDs: messageIDs,
            in: conversation
        )

        inFlightReplyMessageIDs = (inFlightReplyMessageIDs ?? [:]).merging(
            [conversation.id.key: messageIDs],
            uniquingKeysWith: { $1 }
        )

        defer { inFlightReplyMessageIDs?[conversation.id.key] = nil }

        // Typing status is published in one-to-one conversations only.
        let publishesTypingStatus = conversation.participants.count == Int(Floats.typingStatusParticipantCount)
        if publishesTypingStatus {
            await setIsTyping(
                true,
                inConversationWithIDKey: conversation.id.key
            )
        }

        // Sending a message resets the sender's typing status in the
        // same atomic commit, so typing is cleared explicitly only
        // when no reply is sent.
        var didSendReply = false

        do throws(Exception) {
            let user = try await resolveUser()
            let session = context?.session ?? takePreparedSession()
            let replies = try await session.response(to: prompt)

            conversationContexts[conversation.id.key] = .init(
                relayedMessageIDs: Set(conversation.messageIDs).union(
                    context?.relayedMessageIDs ?? []
                ),
                session: session
            )

            await markAsRead(
                prompt.messages,
                in: latestVersion(of: conversation)
            )

            for (index, reply) in replies.enumerated() {
                if index > 0 {
                    if publishesTypingStatus {
                        await setIsTyping(
                            true,
                            inConversationWithIDKey: conversation.id.key
                        )
                    }

                    try? await Task.sleep(
                        for: .milliseconds(Floats.interMessageDelayMilliseconds)
                    )
                }

                _ = try await clientSession.entity.message.sendTextMessage(
                    reply,
                    from: user,
                    in: latestVersion(of: conversation)
                )
            }

            didSendReply = !replies.isEmpty
        } catch {
            conversationContexts[conversation.id.key] = nil
            setIsUndelivered(
                true,
                messageIDs: messageIDs,
                in: conversation
            )

            Logger.log(error)
        }

        guard publishesTypingStatus,
              !didSendReply else { return }

        await setIsTyping(
            false,
            inConversationWithIDKey: conversation.id.key
        )
    }

    private func setIsUndelivered(
        _ isUndelivered: Bool,
        messageIDs: [String],
        in conversation: Conversation
    ) {
        var updatedMessageIDs = undeliveredMessageIDs
        if isUndelivered {
            updatedMessageIDs.formUnion(messageIDs)
        } else {
            updatedMessageIDs.subtract(messageIDs)
        }

        guard updatedMessageIDs != undeliveredMessageIDs else { return }
        undeliveredMessageIDs = updatedMessageIDs

        guard clientSession
            .entity
            .conversation
            .currentConversation?
            .id
            .key == conversation.id.key else { return }

        chatPageViewService.reloadCollectionView()
    }

    private func takePreparedSession() -> LanguageModelSession {
        defer { preparedSession = nil }
        return preparedSession ?? .init(.chatGPT)
    }
}
