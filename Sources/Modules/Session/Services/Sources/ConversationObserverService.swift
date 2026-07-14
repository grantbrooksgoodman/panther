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

        // Dual-format: map (new) or array (legacy).
        let messageIDs: [String]
        let rawMessages = data[Keys.messages.rawValue]

        if let map = rawMessages as? [String: Any] {
            messageIDs = map.keys.sorted()
        } else if let array = rawMessages as? [String] {
            messageIDs = array.filter { $0.hasPrefix("-") }
            if !messageIDs.isEmpty {
                SchemaMigration.flagLegacyMessageIndex(conversationIDKey: idKey)
            }
        } else {
            messageIDs = []
        }

        let activities = try await encodedActivities.map(
            failForEmptyCollection: true
        ) {
            try await Activity(from: $0)
        }

        let metadata = try await ConversationMetadata(from: encodedMetadata)

        // Participants — dual-format: map (new) or
        // array of pipe-delimited strings (legacy).
        let participants: [Participant]
        let rawParticipants = data[Keys.participants.rawValue]

        if let map = rawParticipants as? [String: [String: Any]] {
            var decoded = [Participant]()
            for (uid, values) in map {
                guard let hasDeletedConversation = values[
                    "hasDeletedConversation"
                ] as? Bool,
                    let isTyping = values["isTyping"] as? Bool else {
                    throw .Networking.decodingFailed(
                        data: values,
                        .init(sender: self)
                    )
                }

                decoded.append(
                    Participant(
                        userID: uid,
                        hasDeletedConversation: hasDeletedConversation,
                        isTyping: isTyping
                    )
                )
            }

            participants = decoded
        } else if let array = rawParticipants as? [String] {
            participants = try await array.map(
                failForEmptyCollection: true
            ) {
                try await Participant(from: $0)
            }

            SchemaMigration.flagLegacyParticipants(conversationIDKey: idKey)
        } else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: self)
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
        guard Conversation.canDecode(from: data) else {
            Logger.log(
                .init(
                    "Received non-decodable conversation snapshot.",
                    isReportable: false,
                    userInfo: ["ConversationIDKey": conversationIDKey],
                    metadata: .init(sender: self)
                ),
                domain: .conversationObserver
            )

            return
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
        guard !Task.isCancelled, !isRetry else { return }

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
