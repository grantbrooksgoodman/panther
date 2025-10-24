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

public final class ReactionSessionService {
    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession.conversation) private var conversationSession: ConversationSessionService
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices.notification) private var notificationService: NotificationService

    // MARK: - Properties

    // Dictionary
    @LockIsolated private var uponIsReactingToMessageChangedToFalse = [ReactionSessionServiceEffectID: () -> Void]()
    @LockIsolated private var uponIsReactingToMessageChangedToTrue = [ReactionSessionServiceEffectID: () -> Void]()

    // Other
    public private(set) var isReactingToMessage = false {
        didSet { didSetIsReactingToMessage() }
    }

    // MARK: - Add Effect

    /// Adds an effect to be run once, upon a change in value of `isReactingToMessage`.
    public func addEffectUponIsReactingToMessage(
        changedTo state: Bool,
        id: ReactionSessionServiceEffectID,
        _ effect: @escaping () -> Void
    ) {
        guard state else {
            uponIsReactingToMessageChangedToFalse[id] = effect
            return
        }

        uponIsReactingToMessageChangedToTrue[id] = effect
    }

    // MARK: - React to Message

    @MainActor
    public func react(_ reaction: Reaction, to message: Message) async -> Exception? {
        guard !message.isMock else { return nil }
        guard let conversation = conversationSession.fullConversation,
              let currentUserID = User.currentUserID,
              let messageIndex = conversationSession.currentConversation?.messages?.firstIndex(where: { $0.id == message.id }) else {
            return .init(
                "Failed to resolve required values.",
                metadata: .init(sender: self)
            )
        }

        var reactionMetadata = conversation.reactionMetadata ?? []

        // Remove reaction if same one is already applied

        guard !reactionMetadata
            .filter({ $0.messageID == message.id })
            .map(\.reactions)
            .reduce([], +)
            .filter({ $0.userID == currentUserID })
            .contains(where: { $0.style == reaction.style }) else {
            chatPageViewService.contextMenu?.dismissMenu()
            return await removeReaction(from: message)
        }

        // Filter metadata to remove previous reactions to current message

        isReactingToMessage = true
        reactionMetadata = reactionMetadata.filteringCurrentUserReactions(to: message.id)

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

        chatPageViewService.contextMenu?.dismissMenu()
        reactionMetadata = reactionMetadata.filter { $0 != .empty }.filter { !$0.reactions.isEmpty }
        let updateValueResult = await conversation.updateValue(reactionMetadata, forKey: .reactionMetadata)
        isReactingToMessage = false

        switch updateValueResult {
        case let .success(updatedConversation):
            if let exception = await updatedConversation.setMessages(ids: [message.id]) {
                return exception
            }

            conversationSession.setCurrentConversation(updatedConversation)
            chatPageViewService.reloadItemsWhenSafe(at: [.init(item: 0, section: messageIndex)])
            chatPageViewService.contextMenu?.interaction.addContextMenuInteractionToVisibleCellsOnce()
            return nil

        case let .failure(exception):
            return exception
        }
    }

    // MARK: - Auxiliary

    private func didSetIsReactingToMessage() {
        switch isReactingToMessage {
        case true:
            ContextMenuInteraction.setCanBegin(false)
            guard !uponIsReactingToMessageChangedToTrue.isEmpty else { return }

            Logger.log(.init(
                "Running effects for change of \"isReactingToMessage\" to TRUE.",
                isReportable: false,
                userInfo: ["EnqueuedEffectIDs": uponIsReactingToMessageChangedToTrue.keys.map(\.rawValue)],
                metadata: .init(sender: self)
            ))

            uponIsReactingToMessageChangedToTrue.values.forEach { $0() }
            uponIsReactingToMessageChangedToTrue = .init()

        case false:
            ContextMenuInteraction.setCanBegin(true)
            guard !uponIsReactingToMessageChangedToFalse.isEmpty else { return }

            Logger.log(.init(
                "Running effects for change of \"isReactingToMessage\" to FALSE.",
                isReportable: false,
                userInfo: ["EnqueuedEffectIDs": uponIsReactingToMessageChangedToFalse.keys.map(\.rawValue)],
                metadata: .init(sender: self)
            ))

            uponIsReactingToMessageChangedToFalse.values.forEach { $0() }
            uponIsReactingToMessageChangedToFalse = .init()
        }
    }

    private func notifyUsers(ofReaction reaction: Reaction, to message: Message) async -> Exception? {
        guard let conversation = conversationSession.currentConversation,
              let currentUserID = User.currentUserID,
              let user = conversation
              .users?
              .filter({ !($0.blockedUserIDs ?? []).contains(currentUserID) })
              .first(where: { message.fromAccountID == $0.id }),
              !message.isMock else {
            return .init(
                "Failed to resolve required values.",
                metadata: .init(sender: self)
            )
        }

        if let exception = await notificationService.notify(
            [user],
            ofReaction: reaction,
            message: message,
            conversationIDKey: conversation.id.key,
            isPenPalsConversation: conversation.metadata.isPenPalsConversation
        ) {
            return exception
        }

        return nil
    }

    @MainActor
    private func removeReaction(from message: Message) async -> Exception? {
        guard let conversation = conversationSession.fullConversation,
              let messageIndex = conversationSession.currentConversation?.messages?.firstIndex(where: { $0.id == message.id }),
              !message.isMock,
              let reactionMetadata = conversation.reactionMetadata?.filteringCurrentUserReactions(to: message.id) else {
            return .init(
                "Failed to resolve required values.",
                metadata: .init(sender: self)
            )
        }

        isReactingToMessage = true
        let updateValueResult = await conversation.updateValue(reactionMetadata, forKey: .reactionMetadata)
        isReactingToMessage = false

        switch updateValueResult {
        case let .success(updatedConversation):
            if let exception = await updatedConversation.setMessages(ids: [message.id]) {
                return exception
            }

            conversationSession.setCurrentConversation(updatedConversation)
            chatPageViewService.reloadItemsWhenSafe(at: [.init(item: 0, section: messageIndex)])
            chatPageViewService.contextMenu?.interaction.addContextMenuInteractionToVisibleCellsOnce()
            return nil

        case let .failure(exception):
            return exception
        }
    }
}
