//
//  ReactionSessionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable type_body_length

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem
import Networking

/// The service that applies and removes message reactions.
final class ReactionSessionService {
    // MARK: - Dependencies

    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService
    @Dependency(\.commonServices.notification) private var notificationService: NotificationService

    // MARK: - Properties

    /// A Boolean value that indicates whether a reaction is currently being applied to a message.
    @LockIsolated private(set) var isReactingToMessage = false {
        didSet { didSetIsReactingToMessage() }
    }

    @LockIsolated private var uponIsReactingToMessageChangedToFalse = [ReactionSessionServiceEffectID: () -> Void]()
    @LockIsolated private var uponIsReactingToMessageChangedToTrue = [ReactionSessionServiceEffectID: () -> Void]()

    // MARK: - Add Effect

    /// Registers an effect to run once, the next time ``isReactingToMessage`` is set to the given
    /// value.
    ///
    /// The effect is cleared after it runs. Registering a new effect with the same identifier
    /// and target value replaces the existing one.
    ///
    /// - Parameters:
    ///   - state: The value of ``isReactingToMessage`` that triggers the effect.
    ///   - id: The identifier under which to register the effect.
    ///   - effect: The effect to run.
    func addEffectUponIsReactingToMessage(
        changedTo state: Bool,
        id: ReactionSessionServiceEffectID,
        _ effect: @escaping () -> Void
    ) {
        guard state else { return $uponIsReactingToMessageChangedToFalse[id] = effect }
        $uponIsReactingToMessageChangedToTrue[id] = effect
    }

    // MARK: - React to Message

    /// Applies the given reaction to the given message, or removes it if the same reaction is
    /// already applied.
    ///
    /// Reactions to mock or outbox messages are ignored. The message's sender is notified of the
    /// reaction.
    ///
    /// - Parameters:
    ///   - reaction: The reaction to apply.
    ///   - message: The message to react to.
    ///
    /// - Throws: An `Exception` if the required values cannot be resolved or the write fails.
    @MainActor
    func react(
        _ reaction: Reaction,
        to message: Message
    ) async throws(Exception) {
        guard !message.isMock,
              !message.isOutboxMessage else { return }
        guard let conversation = clientSession.entity.conversation.currentConversation,
              let currentUserID = User.currentUserID,
              let messageIndex = clientSession
              .entity
              .conversation
              .displayedMessages
              .firstIndex(where: { $0.id == message.id }) else {
            throw Exception(
                "Failed to resolve required values.",
                metadata: .init(sender: self)
            )
        }

        let reactionMetadata = conversation.reactionMetadata ?? []

        // Remove reaction if same one is already applied

        guard !reactionMetadata
            .filter({ $0.messageID == message.id })
            .flatMap(\.reactions)
            .filter({ $0.userID == currentUserID })
            .contains(where: { $0.style == reaction.style }) else {
            chatPageViewService.contextMenu?.dismissMenu()
            return try await removeReaction(from: message)
        }

        isReactingToMessage = true

        // Notify users of reaction to message

        Task.background { @MainActor in
            do throws(Exception) {
                try await notifyUsers(
                    ofReaction: reaction,
                    to: message
                )
            } catch {
                Logger.log(error)
            }
        }

        // Update conversation with new reaction metadata

        chatPageViewService.contextMenu?.dismissMenu()
        try await updateConversation(
            conversation,
            messageData: (messageIndex, message),
            newReaction: reaction
        )
    }

    // MARK: - Auxiliary

    private func didSetIsReactingToMessage() {
        switch isReactingToMessage {
        case true:
            Task { @MainActor in
                ContextMenuInteraction.setCanBegin(false)
            }

            let uponIsReactingToMessageChangedToTrue = drainEffects($uponIsReactingToMessageChangedToTrue)
            guard !uponIsReactingToMessageChangedToTrue.isEmpty else { return }

            Logger.log(.init(
                "Running effects for change of \"isReactingToMessage\" to TRUE.",
                isReportable: false,
                userInfo: ["EnqueuedEffectIDs": uponIsReactingToMessageChangedToTrue.keys.map(\.rawValue)],
                metadata: .init(sender: self)
            ))

            runEffects(uponIsReactingToMessageChangedToTrue)

        case false:
            Task { @MainActor in
                ContextMenuInteraction.setCanBegin(true)
            }

            let uponIsReactingToMessageChangedToFalse = drainEffects($uponIsReactingToMessageChangedToFalse)
            guard !uponIsReactingToMessageChangedToFalse.isEmpty else { return }

            Logger.log(.init(
                "Running effects for change of \"isReactingToMessage\" to FALSE.",
                isReportable: false,
                userInfo: ["EnqueuedEffectIDs": uponIsReactingToMessageChangedToFalse.keys.map(\.rawValue)],
                metadata: .init(sender: self)
            ))

            runEffects(uponIsReactingToMessageChangedToFalse)
        }
    }

    private func drainEffects(
        _ effects: LockIsolatedProjection<[ReactionSessionServiceEffectID: () -> Void]>
    ) -> [ReactionSessionServiceEffectID: () -> Void] {
        effects.withValue {
            guard !$0.isEmpty else { return [:] }
            let drained = $0
            $0 = [:]
            return drained
        }
    }

    @MainActor
    private func notifyUsers(
        ofReaction reaction: Reaction,
        to message: Message
    ) async throws(Exception) {
        guard message.fromAccountID != User.currentUserID else { return }
        guard let conversation = clientSession
            .entity
            .conversation
            .currentConversation,
            let currentUserID = User.currentUserID,
            let user = conversation
            .users?
            .filter({ !($0.blockedUserIDs ?? []).contains(currentUserID) })
            .first(where: { message.fromAccountID == $0.id }),
            !message.isMock,
            !message.isOutboxMessage else {
            throw Exception(
                "Failed to resolve required values.",
                metadata: .init(sender: self)
            )
        }

        try await notificationService.notify(
            [user],
            ofReaction: reaction,
            message: message,
            conversationIDKey: conversation.id.key,
            isPenPalsConversation: conversation.metadata.isPenPalsConversation
        )
    }

    @MainActor
    private func removeReaction(
        from message: Message
    ) async throws(Exception) {
        guard let conversation = clientSession.entity.conversation.currentConversation,
              let messageIndex = clientSession
              .entity
              .conversation
              .displayedMessages
              .firstIndex(where: { $0.id == message.id }),
              !message.isMock,
              !message.isOutboxMessage else {
            throw Exception(
                "Failed to resolve required values.",
                metadata: .init(sender: self)
            )
        }

        isReactingToMessage = true
        try await updateConversation(
            conversation,
            messageData: (messageIndex, message),
            newReaction: nil
        )
    }

    private func runEffects(_ effects: [ReactionSessionServiceEffectID: () -> Void]) {
        effects.values.forEach { $0() }
    }

    @MainActor
    private func updateConversation(
        _ conversation: Conversation,
        messageData: (index: Int, message: Message),
        newReaction: Reaction?
    ) async throws(Exception) {
        guard let currentUserID = User.currentUserID else {
            throw Exception(
                "Current user ID has not been set.",
                metadata: .init(sender: self)
            )
        }

        let encodedReactionStyle = newReaction?.style.encodedValue
        let messageID = messageData.message.id
        let reactionUserID = newReaction?.userID

        // Atomically read-modify-write the reactionMetadata
        // node; didWrite commits the hash and participant
        // token fan-out and upserts to the session store.

        let updatedConversation: Conversation
        do throws(Exception) {
            updatedConversation = try await conversation.update(
                \.reactionMetadata,
                applyingRaw: { currentValue in
                    typealias ReactionKey = Reaction.SerializableKey
                    typealias ReactionMetadataKey = ReactionMetadata.SerializableKey

                    var metadata = (currentValue as? [[String: Any]]) ?? []

                    // Strip sentinel entries.
                    metadata = metadata.filter {
                        ($0[ReactionMetadataKey.messageID.rawValue] as? String) != String.bangQualifiedEmpty
                    }

                    // Remove current user's reactions to this message.
                    metadata = metadata.compactMap { entry -> [String: Any]? in
                        guard (entry[
                            ReactionMetadataKey.messageID.rawValue
                        ] as? String) == messageID else { return entry }

                        var reactions = (entry[
                            ReactionMetadataKey.reactions.rawValue
                        ] as? [[String: Any]]) ?? []

                        reactions.removeAll { ($0[
                            ReactionKey.userID.rawValue
                        ] as? String) == currentUserID }

                        guard !reactions.isEmpty else { return nil }

                        var updated = entry
                        updated[ReactionMetadataKey.reactions.rawValue] = reactions
                        return updated
                    }

                    // Add new reaction if provided.
                    if let encodedReactionStyle,
                       let reactionUserID {
                        let reactionStyle = Reaction.Style(
                            encodedValue: encodedReactionStyle
                        ) ?? .love

                        let reaction = Reaction(
                            reactionStyle,
                            userID: reactionUserID
                        )

                        if let index = metadata.firstIndex(where: {
                            ($0[ReactionMetadataKey.messageID.rawValue] as? String) == messageID
                        }) {
                            var reactions = (metadata[index][
                                ReactionMetadataKey.reactions.rawValue
                            ] as? [[String: Any]]) ?? []

                            reactions.append(reaction.encoded)
                            metadata[index][
                                ReactionMetadataKey.reactions.rawValue
                            ] = reactions
                        } else {
                            metadata.append(
                                ReactionMetadata(
                                    messageID: messageID,
                                    reactions: [reaction]
                                ).encoded
                            )
                        }
                    }

                    // Return empty sentinel if no reactions remain.
                    guard !metadata.isEmpty else { return [ReactionMetadata.empty.encoded] }
                    return metadata
                }
            )
        } catch {
            isReactingToMessage = false
            throw error
        }

        isReactingToMessage = false
        try await updatedConversation.resolveMessages(
            ids: [
                messageData.message.id,
            ]
        )

        guard chatPageState.isPresented,
              clientSession
              .entity
              .conversation
              .currentConversation?
              .id
              .key == conversation.id.key else { return }

        clientSession.entity.conversation.updateDisplayedMessages()
        chatPageViewService.reloadItemsWhenSafe(at: [.init(
            item: 0,
            section: messageData.index
        )])

        chatPageViewService
            .contextMenu?
            .interaction
            .addContextMenuInteractionToVisibleCellsOnce()

        guard messageData
            .message
            .contentType
            .isAudio else { return }

        chatPageViewService
            .audioMessagePlayback?
            .updateDurationLabelIfNeeded(forMessage: messageData.message)
    }
}

// swiftlint:enable type_body_length
