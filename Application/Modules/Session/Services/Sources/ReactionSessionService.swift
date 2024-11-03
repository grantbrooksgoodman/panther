//
//  ReactionSessionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem
import Networking

public struct ReactionSessionService {
    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession.conversation) private var conversationSession: ConversationSessionService
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices.notification) private var notificationService: NotificationService

    // MARK: - Properties

    @Persistent(.currentUserID) private var currentUserID: String?

    // MARK: - React to Message

    public func react(_ reaction: Reaction, to message: Message) async -> Exception? {
        guard let conversation = conversationSession.currentConversation,
              let currentUserID,
              let messageIndex = conversation.messages?.firstIndex(where: { $0.id == message.id }),
              !message.isMock else {
            return .init(
                "Failed to resolve required values.",
                metadata: [self, #file, #function, #line]
            )
        }

        var reactionMetadata = conversation.reactionMetadata ?? []

        // Remove reaction if same one is already applied

        guard !reactionMetadata
            .filter({ $0.messageID == message.id })
            .filter({ $0.reactions.contains(where: { $0.userID == currentUserID }) })
            .contains(where: { $0.reactions.contains(where: { $0.style == reaction.style }) }) else {
            dismissMenu()
            return await removeReaction(from: message)
        }

        // Filter metadata to remove previous reactions to current message

        reactionMetadata = reactionMetadata.filteringCurrentUserReactions(to: message)

        // Add new reaction to metadata

        if let existingMetadata = reactionMetadata.first(where: { $0.messageID == message.id }) {
            var newReactions = existingMetadata.reactions
            newReactions.append(reaction)

            let newMetadata = ReactionMetadata(
                messageID: message.id,
                reactions: newReactions
            )

            reactionMetadata.removeAll(where: { $0.messageID == message.id })
            reactionMetadata.append(newMetadata)
        } else {
            reactionMetadata.append(
                .init(
                    messageID: message.id,
                    reactions: [reaction]
                )
            )
        }

        // Notify users of reaction to message

        Task.background {
            guard let exception = await notifyUsers(ofReaction: reaction, to: message) else { return }
            Logger.log(exception)
        }

        // Update conversation with new metadata

        dismissMenu()
        reactionMetadata = reactionMetadata.filter { !$0.reactions.isEmpty }
        let updateValueResult = await conversation.updateValue(reactionMetadata, forKey: .reactionMetadata)

        switch updateValueResult {
        case let .success(updatedConversation): // TODO: Audit the efficacy of the below code.
            conversationSession.setCurrentConversation(updatedConversation)
            chatPageViewService.reloadItemsWhenSafe(at: [.init(item: 0, section: messageIndex)])
            chatPageViewService.contextMenu?.addContextMenuInteractionToVisibleCellsOnce()
            return nil

        case let .failure(exception):
            return exception
        }
    }

    // MARK: - Auxiliary

    private func dismissMenu() {
        Task { @MainActor in
            UIView.dismissCurrentContextMenu()
        }
    }

    private func notifyUsers(ofReaction reaction: Reaction, to message: Message) async -> Exception? {
        guard let conversation = conversationSession.currentConversation,
              let currentUserID,
              let users = conversation.users?.filter({ !($0.blockedUserIDs ?? []).contains(currentUserID) }),
              !message.isMock else {
            return .init(
                "Failed to resolve required values.",
                metadata: [self, #file, #function, #line]
            )
        }

        if let exception = await notificationService.notify(
            users,
            ofReaction: reaction,
            message: message,
            conversationIDKey: conversation.id.key
        ) {
            return exception
        }

        return nil
    }

    @MainActor
    private func removeReaction(from message: Message) async -> Exception? {
        guard let conversation = conversationSession.currentConversation,
              let messageIndex = conversation.messages?.firstIndex(where: { $0.id == message.id }),
              !message.isMock,
              let reactionMetadata = conversation.reactionMetadata?.filteringCurrentUserReactions(to: message) else {
            return .init(
                "Failed to resolve required values.",
                metadata: [self, #file, #function, #line]
            )
        }

        let updateValueResult = await conversation.updateValue(reactionMetadata, forKey: .reactionMetadata)

        switch updateValueResult {
        case let .success(conversation): // TODO: Audit the efficacy of the below code.
            conversationSession.setCurrentConversation(conversation)
            chatPageViewService.reloadItemsWhenSafe(at: [.init(item: 0, section: messageIndex)])
            chatPageViewService.contextMenu?.addContextMenuInteractionToVisibleCellsOnce()
            return nil

        case let .failure(exception):
            return exception
        }
    }
}
