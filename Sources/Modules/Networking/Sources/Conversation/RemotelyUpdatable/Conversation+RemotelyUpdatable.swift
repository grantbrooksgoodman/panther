//
//  Conversation+RemotelyUpdatable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

extension Conversation: RemotelyUpdatable {
    // MARK: - Properties

    var identifier: String { id.key }

    // MARK: - Serializable Key

    static func serializableKey(
        for keyPath: PartialKeyPath<Conversation>
    ) -> SerializableKey? {
        switch keyPath {
        case \.activities: .activities
        case \.messages: .messages
        case \.participants: .participants
        case \.reactionMetadata: .reactionMetadata
        default: nil
        }
    }

    // MARK: - Modify Key

    func modifyKey(
        _ key: SerializableKey,
        withValue value: Any
    ) -> Conversation? {
        switch key {
        case .encodedHash,
             .id:
            return nil

        case .activities:
            return (value as? [Activity]).map {
                updateIDHash(copying(activities: $0))
            }

        case .messages:
            guard let value = value as? [Message] else { return nil }
            return updateIDHash(
                copying(
                    messageIDs: value.map(\.id).unique
                ).copying(
                    messages: value.uniquedByID
                )
            )

        case .metadata:
            return (value as? ConversationMetadata).map {
                updateIDHash(copying(metadata: $0))
            }

        case .participants:
            return (value as? [Participant]).map {
                updateIDHash(copying(participants: $0))
            }

        case .reactionMetadata:
            guard let value = value as? [ReactionMetadata] else { return nil }
            return updateIDHash(copying(
                reactionMetadata: value.allSatisfy { $0 == .empty } ||
                    value.isEmpty ? nil : value
            ))
        }
    }

    // MARK: - Updates Values

    func updateValues(
        with data: [PartialKeyPath<Conversation>: Any] // swiftformat:disable all
    ) async throws(Exception) -> Conversation { // swiftformat:enable all
        @Dependency(\.networking) var networking: NetworkServices
        @Dependency(\.clientSession.user) var userSession: UserSessionService

        var updated = filteringSystemMessages
        for keyPair in data {
            guard let key = Self.serializableKey(for: keyPair.key) else {
                throw .Networking.notRemotelyUpdatable(
                    key: keyPair.key,
                    .init(sender: self)
                )
            }

            guard let modified = updated.modifyKey(
                key,
                withValue: keyPair.value
            ) else {
                throw .Networking.typeMismatch(
                    key: key,
                    type: type(of: keyPair.value),
                    .init(sender: self)
                )
            }

            updated = modified
        }

        // NIT: Can do updateChildValues with encoded filtering all not equal to keys in data.
        let conversationKeyPath = "\(NetworkPath.conversations.rawValue)/\(updated.id.key)/"
        if let exception = await networking.database.setValue(
            updated.encoded.filter { $0.key != Conversation.SerializableKey.id.rawValue },
            forKey: conversationKeyPath
        ) {
            throw exception
        }

        if let exception = await propagateUpdatesToUsers(in: updated) {
            throw exception
        }

        if data.keys.contains(\.activities) {
            if let exception = await updated.setUsers(forceUpdate: true) {
                throw exception
            }
        }

        networking.conversationService.archive.addValue(updated)
        return updated
    }

    // MARK: - Will Write

    func willWrite(
        _ value: Any,
        forKey key: SerializableKey,
        updating updated: Conversation // swiftformat:disable all
    ) async throws(Exception) -> WriteAction<Conversation> { // swiftformat:enable all
        guard key == .messages,
              let messageIDs = (value as? [Message])?.filteringSystemMessages.map(\.id),
              !messageIDs.isEmpty else { return .proceed }

        if let exception = await addMessageIDs(messageIDs) {
            throw exception
        }

        return try await .handled(updateIsTyping(updated))
    }

    // MARK: - Did Update

    func didWrite(
        _ updated: Conversation,
        forKey key: SerializableKey // swiftformat:disable all
    ) async throws(Exception) -> Conversation { // swiftformat:enable all
        @Dependency(\.networking) var networking: NetworkServices

        defer { networking.conversationService.archive.addValue(updated) }
        guard updated.id.hash != id.hash else { return updated }

        if let exception = await networking.database.setValue(
            updated.id.hash,
            forKey: [
                networkPath.rawValue,
                identifier,
                SerializableKey.encodedHash.rawValue,
            ].joined(separator: "/")
        ) {
            throw exception
        }

        if let exception = await propagateUpdatesToUsers(in: updated) {
            throw exception
        }

        guard key == .activities else { return updated }
        if let exception = await updated.setUsers(forceUpdate: true) {
            throw exception
        }

        return updated
    }

    // MARK: - Auxiliary

    /// Ensures updates take into account any messages sent during execution of `update` logic.
    /// We disregard modification of the local value, since this scenario should trigger a latent call to `ConversationsPageViewObserver.updateConversations()`.
    private func addMessageIDs(_ messageIDs: [String]) async -> Exception? {
        @Dependency(\.networking) var networking: NetworkServices

        let messagesKeyPath = [
            NetworkPath.conversations.rawValue,
            id.key,
            Conversation.SerializableKey.messages.rawValue,
        ].joined(separator: "/")

        let currentMessageIDs: [String]
        var newMessageIDs = messageIDs

        do {
            currentMessageIDs = try await networking.database.getValues(
                at: messagesKeyPath,
                cacheStrategy: .disregardCache
            )
        } catch {
            return error
        }

        newMessageIDs += currentMessageIDs
        if let exception = await networking.database.setValue(
            newMessageIDs.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : newMessageIDs.unique,
            forKey: messagesKeyPath
        ) {
            return exception
        }

        return nil
    }

    private func propagateUpdatesToUsers(
        in conversation: Conversation
    ) async -> Exception? {
        @Dependency(\.clientSession.user) var userSession: UserSessionService

        if let exception = await conversation.setUsers(forceUpdate: true) {
            return exception
        }

        guard var users = conversation.users else {
            return .init(
                "Failed to set users on conversation.",
                metadata: .init(sender: self)
            )
        }

        if let currentUser = userSession.currentUser {
            users.append(currentUser)
        }

        return await withTaskGroup(
            of: Exception?.self,
            returning: [Exception].self
        ) { taskGroup in
            for user in users {
                guard var conversationIDs = user.conversationIDs,
                      let index = conversationIDs.firstIndex(where: {
                          $0.key == conversation.id.key
                      }) else { continue }

                conversationIDs.removeAll(where: { $0.key == conversation.id.key })
                conversationIDs.insert(conversation.id, at: index)

                taskGroup.addTask { // swiftformat:disable all
                    do throws(Exception) { // swiftformat:enable all
                        _ = try await user.update(
                            \.conversationIDs,
                            to: conversationIDs
                        )
                        return nil
                    } catch {
                        return error
                    }
                }
            }

            var exceptions = [Exception]()
            for await exception in taskGroup {
                if let exception {
                    exceptions.append(exception)
                }
            }

            return exceptions
        }.compiledException
    }

    private func updateIDHash(_ conversation: Conversation) -> Conversation {
        conversation.copying(
            id: .init(
                key: conversation.id.key,
                hash: conversation.encodedHash
            )
        )
    }

    /// It's optimal to set `isTyping` to `false` in the same call as appending messages during a send operation so the conversation hash doesn't need to be recomputed twice.
    private func updateIsTyping(
        _ conversation: Conversation // swiftformat:disable all
    ) async throws(Exception) -> Conversation { // swiftformat:enable all
        @Dependency(\.networking) var networking: NetworkServices

        guard let currentUserParticipant = conversation.currentUserParticipant else {
            throw Exception(
                "Failed to resolve current user participant.",
                metadata: .init(sender: self)
            )
        }

        var newParticipants = [Participant]()
        newParticipants = participants.filter { $0 != currentUserParticipant }
        newParticipants.append(.init(
            userID: currentUserParticipant.userID,
            hasDeletedConversation: currentUserParticipant.hasDeletedConversation,
            isTyping: false
        ))

        // TODO: Audit whether or not it is necessary to update the ID hash here.
        let updatedConversation = updateIDHash(
            conversation.copying(participants: newParticipants)
        )

        if let exception = await networking.database.setValue(
            updatedConversation.participants.map(\.encoded),
            forKey: "\(NetworkPath.conversations.rawValue)/\(updatedConversation.id.key)/\(SerializableKey.participants.rawValue)"
        ) {
            throw exception
        }

        return updatedConversation
    }
}
