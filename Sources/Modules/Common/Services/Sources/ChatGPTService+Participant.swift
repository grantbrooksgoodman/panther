//
//  ChatGPTService+Participant.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 26/10/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

extension ChatGPTService {
    // MARK: - Mark as Read

    /// Marks the given messages as read by ChatGPT.
    ///
    /// Failures are logged rather than thrown.
    ///
    /// - Parameters:
    ///   - messages: The messages to mark as read.
    ///   - conversation: The conversation containing the messages.
    func markAsRead(
        _ messages: [Message],
        in conversation: Conversation
    ) async {
        do throws(Exception) {
            try await conversation.updateReadDate(
                for: messages,
                userID: CommonConstants.chatGPTUserID
            )
        } catch {
            Logger.log(error)
        }
    }

    // MARK: - Set Is Typing

    /// Writes ChatGPT's typing status in the given conversation, and
    /// applies it to the conversation's copy in the session store.
    ///
    /// Failures are logged rather than thrown.
    ///
    /// - Parameters:
    ///   - isTyping: ChatGPT's new typing status.
    ///   - conversationIDKey: The identifier key of the conversation.
    func setIsTyping(
        _ isTyping: Bool,
        inConversationWithIDKey conversationIDKey: String
    ) async {
        @Dependency(\.networking.database) var database: DatabaseDelegate
        @Dependency(\.clientSession.store) var sessionStore: SessionStore

        let path = [
            NetworkPath.conversations.rawValue,
            conversationIDKey,
            Conversation.SerializableKey.participants.rawValue,
            CommonConstants.chatGPTUserID,
            Participant.SerializableKey.isTyping.rawValue,
        ].joined(separator: "/")

        do throws(Exception) {
            let database = UncheckedSendable(database)
            try await database.wrappedValue.commit([path: isTyping])
        } catch {
            return Logger.log(error)
        }

        guard let conversation = sessionStore.getConversation(
            idKey: conversationIDKey
        ) else { return }

        sessionStore.upsertConversation(
            conversation.copying(
                participants: conversation.participants.map {
                    .init(
                        userID: $0.userID,
                        hasDeletedConversation: $0.hasDeletedConversation,
                        isTyping: $0.userID == CommonConstants.chatGPTUserID ? isTyping : $0.isTyping
                    )
                }
            )
        )
    }
}
