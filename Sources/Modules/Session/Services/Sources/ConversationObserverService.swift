//
//  ConversationObserverService.swift
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

final class ConversationObserverService: @unchecked Sendable {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.clientSession.store) private var sessionStore: SessionStore

    // MARK: - Properties

    private var observationTask: Task<Void, Never>?

    // MARK: - Observation

    func startObserving(conversationIDKey: String) {
        observationTask?.cancel()
        observationTask = nil

        Logger.log(
            .init(
                "Started observing conversation.",
                isReportable: false,
                userInfo: ["ConversationIDKey": conversationIDKey],
                metadata: .init(sender: self)
            ),
            domain: .conversationObserver
        )

        observationTask = Task {
            await observe(
                conversationIDKey: conversationIDKey,
                isRetry: false
            )
        }
    }

    func stopObserving() {
        if observationTask == nil {
            Logger.log(
                .init(
                    "No active observer to stop.",
                    isReportable: false,
                    metadata: .init(sender: self)
                ),
                domain: .conversationObserver
            )
        } else {
            Logger.log(
                "Stopped observing conversation.",
                domain: .conversationObserver,
                sender: self
            )
        }

        observationTask?.cancel()
        observationTask = nil
    }

    // MARK: - Auxiliary

    private func decodeConversation(
        from data: [String: Any],
        idKey: String
    ) async throws(Exception) -> Conversation {
        typealias Keys = Conversation.SerializableKey

        let encodedHash = data[Keys.encodedHash.rawValue] as? String ?? ""

        guard data[Keys.id.rawValue] is String,
              let encodedActivities = data[
                  Keys.activities.rawValue
              ] as? [[String: Any]],
              let encodedMetadata = data[
                  Keys.metadata.rawValue
              ] as? [String: Any],
              let encodedReactionMetadata = data[
                  Keys.reactionMetadata.rawValue
              ] as? [[String: Any]] else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: self)
            )
        }

        let messageIDs: [String] = if let map = data[Keys.messages.rawValue] as? [String: Any] {
            map.keys.sorted()
        } else {
            []
        }

        let activities = try await encodedActivities.map(
            failForEmptyCollection: true
        ) {
            try await Activity(from: $0)
        }

        let metadata = try await ConversationMetadata(from: encodedMetadata)

        guard let participantMap = data[Keys.participants.rawValue] as? [String: [String: Any]] else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: self)
            )
        }

        var participants = [Participant]()
        for (userID, values) in participantMap {
            guard let hasDeletedConversation = values[
                Participant.SerializableKey.hasDeletedConversation.rawValue
            ] as? Bool,
                let isTyping = values[
                    Participant.SerializableKey.isTyping.rawValue
                ] as? Bool else {
                throw .Networking.decodingFailed(
                    data: values,
                    .init(sender: self)
                )
            }

            participants.append(
                Participant(
                    userID: userID,
                    hasDeletedConversation: hasDeletedConversation,
                    isTyping: isTyping
                )
            )
        }

        let reactionMetadata = try await encodedReactionMetadata.map(
            failForEmptyCollection: true
        ) {
            try await ReactionMetadata(from: $0)
        }

        return Conversation(
            ConversationID(
                key: idKey,
                hash: encodedHash
            ),
            activities: activities,
            messageIDs: messageIDs.isBangQualifiedEmpty
                ? .bangQualifiedEmpty
                : messageIDs,
            metadata: metadata,
            participants: participants,
            reactionMetadata: reactionMetadata.allSatisfy {
                $0 == .empty
            } ? nil : reactionMetadata
        )
    }

    private func handleSnapshot(
        _ data: [String: Any],
        conversationIDKey: String
    ) async {
        let data = makeDecodable(
            data,
            conversationIDKey: conversationIDKey
        )

        guard Conversation.canDecode(from: data) else {
            return Logger.log(
                .init(
                    "Received non-decodable conversation snapshot.",
                    userInfo: ["ConversationIDKey": conversationIDKey],
                    metadata: .init(sender: self)
                ),
                domain: .conversationObserver,
                with: .toastInPrerelease
            )
        }

        do throws(Exception) {
            let conversation = try await decodeConversation(
                from: data,
                idKey: conversationIDKey
            )

            let existingMessageIDs = Set(
                sessionStore.getConversation(
                    idKey: conversationIDKey
                )?.messageIDs ?? []
            )

            let newMessageIDs = Set(
                conversation.messageIDs
            ).subtracting(existingMessageIDs)

            if !newMessageIDs.isEmpty {
                try await conversation.resolveMessages(ids: newMessageIDs)
            }

            sessionStore.upsertConversation(conversation)
        } catch {
            Logger.log(
                .init(
                    error,
                    metadata: .init(sender: self)
                ),
                domain: .conversationObserver
            )
        }
    }

    private func makeDecodable(
        _ data: [String: Any],
        conversationIDKey: String
    ) -> [String: Any] {
        let hash = data[
            Conversation.SerializableKey.encodedHash.rawValue
        ] ?? String.bangQualifiedEmpty
        var data = data
        data[
            Conversation.SerializableKey.id.rawValue
        ] = "\(conversationIDKey) | \(hash)"
        return data
    }

    private func observe(
        conversationIDKey: String,
        isRetry: Bool
    ) async {
        do {
            for try await dictionary: [String: Any] in networking.database.observe(
                path: [
                    NetworkPath.conversations.rawValue,
                    conversationIDKey,
                ].joined(separator: "/")
            ) {
                guard !Task.isCancelled else { return }
                await handleSnapshot(
                    dictionary,
                    conversationIDKey: conversationIDKey
                )
            }
        } catch {
            guard !Task.isCancelled else { return }
            Logger.log(
                .init(
                    error,
                    metadata: .init(sender: self)
                ),
                domain: .conversationObserver
            )
        }

        // Stream terminated. Retry once after 2 s;
        // the user-node pipeline remains the safety net.
        guard !Task.isCancelled,
              !isRetry else { return }

        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled else { return }

        Logger.log(
            "Retrying conversation observation after stream termination.",
            domain: .conversationObserver,
            sender: self
        )

        await observe(
            conversationIDKey: conversationIDKey,
            isRetry: true
        )
    }
}
