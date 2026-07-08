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
        let messageIDs = messageIDs.filter { $0.hasPrefix("-") }
        let reactionMetadata = reactionMetadata?.map(\.encoded) ?? [ReactionMetadata.empty.encoded]
        return [
            Keys.id.rawValue: id.encoded,
            Keys.activities.rawValue: activities?.map(\.encoded) ?? [Activity.empty.encoded],
            Keys.encodedHash.rawValue: encodedHash,
            Keys.messages.rawValue: messageIDs.isBangQualifiedEmpty ? .bangQualifiedEmpty : messageIDs,
            Keys.metadata.rawValue: metadata.encoded,
            Keys.participants.rawValue: participants.map(\.encoded),
            Keys.reactionMetadata.rawValue: reactionMetadata,
        ]
    }

    // MARK: - Init

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
              let encodedParticipants = data[Keys.participants.rawValue] as? [String],
              let encodedReactionMetadata = data[Keys.reactionMetadata.rawValue] as? [[String: Any]],
              let messageIDs = data[Keys.messages.rawValue] as? [String] else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: Self.self)
            )
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

        // Decode participants

        let participants = try await encodedParticipants.map(
            failForEmptyCollection: true
        ) {
            try await Participant(from: $0)
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
              ] as? [String],
              let encodedParticipants = data[Keys.participants.rawValue] as? [String],
              encodedParticipants.allSatisfy({ Participant.canDecode(from: $0) }),
              encodedParticipants.count > 1,
              encodedMessageRecipientConsentAcknowledgementData.count == encodedPenPalsSharingData.count,
              encodedPenPalsSharingData.count == encodedParticipants.count,
              let encodedReactionMetadata = data[Keys.reactionMetadata.rawValue] as? [[String: Any]],
              encodedReactionMetadata.allSatisfy({ ReactionMetadata.canDecode(from: $0) }),
              data[Keys.messages.rawValue] is [String] else { return false }

        return true
    }
}
