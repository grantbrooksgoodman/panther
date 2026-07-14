//
//  Conversation+Serializable.swift
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

extension Conversation: Serializable {
    // MARK: - Type Aliases

    private typealias Keys = SerializableKey

    // MARK: - Types

    enum SerializableKey: String {
        case id
        case activities
        case encodedHash = "hash"
        case messages
        case metadata
        case participants
        case reactionMetadata
    }

    // MARK: - Properties

    var encoded: [String: Any] {
        let filteredMessageIDs = messageIDs.filter { $0.hasPrefix("-") }
        let reactionMetadata = reactionMetadata?.map(\.encoded) ?? [ReactionMetadata.empty.encoded]

        var messagesMap = [String: Bool]()
        for messageID in filteredMessageIDs {
            messagesMap[messageID] = true
        }

        var participantsMap = [String: [String: Any]]()
        for participant in participants {
            participantsMap[participant.userID] = [
                "hasDeletedConversation": participant.hasDeletedConversation,
                "isTyping": participant.isTyping,
            ]
        }

        return [
            Keys.id.rawValue: id.encoded,
            Keys.activities.rawValue: activities?.map(\.encoded) ?? [Activity.empty.encoded],
            Keys.encodedHash.rawValue: encodedHash,
            Keys.messages.rawValue: messagesMap.isEmpty ? [String: Bool]() : messagesMap,
            Keys.metadata.rawValue: metadata.encoded,
            Keys.participants.rawValue: participantsMap,
            Keys.reactionMetadata.rawValue: reactionMetadata,
        ]
    }

    // MARK: - Init

    // swiftlint:disable:next function_body_length
    init(
        from data: [String: Any]
    ) async throws(Exception) {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        @Dependency(\.networking.messageService) var messageService: MessageService
        @Dependency(\.clientSession.store) var sessionStore: SessionStore

        // Deserialize raw data

        guard let id = data[Keys.id.rawValue] as? String,
              let encodedActivities = data[Keys.activities.rawValue] as? [[String: Any]],
              let encodedMetadata = data[Keys.metadata.rawValue] as? [String: Any],
              let encodedReactionMetadata = data[Keys.reactionMetadata.rawValue] as? [[String: Any]] else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: Self.self)
            )
        }

        // Dual-format: map (new) or array (legacy).
        // Map keys are Firebase push IDs (chronologically
        // ordered); sorted keys give ascending sent-order.
        let messageIDs: [String]
        let rawMessages = data[Keys.messages.rawValue]
        if let map = rawMessages as? [String: Any] {
            messageIDs = map.keys.sorted()
        } else if let array = rawMessages as? [String] {
            messageIDs = array.filter { $0.hasPrefix("-") }
            if let conversationKey = id.components(separatedBy: " | ").first,
               !messageIDs.isEmpty {
                SchemaMigration.flagLegacyMessageIndex(conversationIDKey: conversationKey)
            }
        } else {
            messageIDs = []
        }

        // Decode conversation ID

        let conversationID = try await ConversationID(from: id)

        // Decode activities

        let activities = try await encodedActivities.map(
            failForEmptyCollection: true
        ) {
            try await Activity(from: $0)
        }

        // Decode metadata

        let metadata = try await ConversationMetadata(
            from: encodedMetadata
        )

        // Decode participants — dual-format: map (new) or
        // array of pipe-delimited strings (legacy).

        let participants: [Participant]
        let rawParticipants = data[Keys.participants.rawValue]

        if let map = rawParticipants as? [String: [String: Any]] {
            var decoded = [Participant]()
            for (uid, values) in map {
                guard let hasDeletedConversation = values["hasDeletedConversation"] as? Bool,
                      let isTyping = values["isTyping"] as? Bool else {
                    throw .Networking.decodingFailed(
                        data: values,
                        .init(sender: Self.self)
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

            if let conversationKey = id.components(separatedBy: " | ").first {
                SchemaMigration.flagLegacyParticipants(conversationIDKey: conversationKey)
            }
        } else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: Self.self)
            )
        }

        // Decode reaction metadata

        let reactionMetadata = try await encodedReactionMetadata.map(
            failForEmptyCollection: true
        ) {
            try await ReactionMetadata(from: $0)
        }

        // Synthesize conversation

        guard let currentUserParticipant = participants.firstWithCurrentUserID,
              !currentUserParticipant.hasDeletedConversation else {
            Logger.log(
                .init(
                    "Skipping message retrieval for conversation in which current user is not participating or has deleted.",
                    isReportable: false,
                    userInfo: [
                        "ConversationIDKey": conversationID.key,
                        "ConversationIDHash": conversationID.hash,
                    ],
                    metadata: .init(sender: Self.self)
                ),
                domain: .conversation
            )

            self.init(
                conversationID,
                activities: activities,
                messageIDs: messageIDs.isBangQualifiedEmpty ? .bangQualifiedEmpty : messageIDs,
                metadata: metadata,
                participants: participants,
                reactionMetadata: reactionMetadata.allSatisfy { $0 == .empty } ? nil : reactionMetadata
            )
            return
        }

        guard !messageIDs.isBangQualifiedEmpty else {
            self.init(
                conversationID,
                activities: activities,
                messageIDs: .bangQualifiedEmpty,
                metadata: metadata,
                participants: participants,
                reactionMetadata: reactionMetadata.allSatisfy { $0 == .empty } ? nil : reactionMetadata
            )
            return
        }

        let messages = try await messageService.getMessages(
            ids: messageIDs
        )

        guard !messages.isEmpty,
              messages.count == messageIDs.count else {
            throw Exception(
                "Mismatched ratio returned.",
                metadata: .init(sender: Self.self)
            )
        }

        // Fetched during deserialization; bypasses RemotelyUpdatable.update.
        sessionStore.upsertMessages(Set(messages))
        self.init(
            conversationID,
            activities: activities,
            messageIDs: messageIDs,
            metadata: metadata,
            participants: participants,
            reactionMetadata: reactionMetadata.allSatisfy { $0 == .empty } ? nil : reactionMetadata
        )
    }

    // MARK: - Methods

    static func canDecode(
        from data: [String: Any]
    ) -> Bool {
        guard data[Keys.id.rawValue] is String,
              let encodedActivities = data[Keys.activities.rawValue] as? [[String: Any]],
              encodedActivities.allSatisfy({ Activity.canDecode(from: $0) }),
              let encodedMetadata = data[Keys.metadata.rawValue] as? [String: Any],
              ConversationMetadata.canDecode(from: encodedMetadata), // swiftlint:disable:next identifier_name
              let encodedMessageRecipientConsentAcknowledgementData = encodedMetadata[
                  ConversationMetadata
                      .SerializableKey
                      .messageRecipientConsentAcknowledgementData
                      .rawValue
              ] as? [String],
              let encodedPenPalsSharingData = encodedMetadata[
                  ConversationMetadata
                      .SerializableKey
                      .penPalsSharingData
                      .rawValue
              ] as? [String] else { return false }

        // Dual-format: map (new) or array (legacy).
        let participantCount: Int
        if let map = data[Keys.participants.rawValue] as? [String: [String: Any]] {
            participantCount = map.count
        } else if let array = data[Keys.participants.rawValue] as? [String],
                  array.allSatisfy({ Participant.canDecode(from: $0) }) {
            participantCount = array.count
        } else {
            return false
        }

        guard participantCount > 1,
              encodedMessageRecipientConsentAcknowledgementData.count == encodedPenPalsSharingData.count,
              encodedPenPalsSharingData.count == participantCount,
              let encodedReactionMetadata = data[Keys.reactionMetadata.rawValue] as? [[String: Any]],
              encodedReactionMetadata.allSatisfy({ ReactionMetadata.canDecode(from: $0) }),
              data[Keys.messages.rawValue] is [String: Any] ||
              data[Keys.messages.rawValue] is [String] ||
              data[Keys.messages.rawValue] == nil else { return false }

        return true
    }
}
