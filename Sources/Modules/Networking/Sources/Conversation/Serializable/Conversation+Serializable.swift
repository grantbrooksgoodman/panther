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
                Participant.SerializableKey.hasDeletedConversation.rawValue: participant.hasDeletedConversation,
                Participant.SerializableKey.isTyping.rawValue: participant.isTyping,
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

    init(
        from data: [String: Any]
    ) async throws(Exception) {
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

        let messageIDs: [String] = if let map = data[
            Keys.messages.rawValue
        ] as? [String: Any] {
            map.keys.sorted()
        } else {
            []
        }

        // Decode conversation ID

        let conversationID = try await ConversationID(from: id)

        // Decode participants

        guard let participantMap = data[
            Keys.participants.rawValue
        ] as? [String: [String: Any]] else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: Self.self)
            )
        }

        var participants = [Participant]()
        for (userID, values) in participantMap {
            guard let hasDeletedConversation = values[
                Participant.SerializableKey.hasDeletedConversation.rawValue
            ] as? Bool, let isTyping = values[
                Participant.SerializableKey.isTyping.rawValue
            ] as? Bool else {
                throw .Networking.decodingFailed(
                    data: values,
                    .init(sender: Self.self)
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

        // Decode reaction metadata

        let reactionMetadata = try await encodedReactionMetadata.parallelMap(
            failForEmptyCollection: true
        ) {
            try await ReactionMetadata(from: $0)
        }

        // Synthesize conversation

        // Message resolution is deferred to resolveMessages /
        // resolveMessagesOnCurrentUserConversations; decoding
        // only records the message IDs.

        if participants.firstWithCurrentUserID == nil ||
            participants.firstWithCurrentUserID?.hasDeletedConversation == true {
            Logger.log(
                .init(
                    "Current user is not participating in or has deleted this conversation.",
                    isReportable: false,
                    userInfo: [
                        "ConversationIDKey": conversationID.key,
                        "ConversationIDHash": conversationID.hash,
                    ],
                    metadata: .init(sender: Self.self)
                ),
                domain: .conversation
            )
        }

        try await self.init(
            conversationID,
            activities: encodedActivities.parallelMap(
                failForEmptyCollection: true
            ) { try await Activity(from: $0) },
            messageIDs: messageIDs.isBangQualifiedEmpty ? .bangQualifiedEmpty : messageIDs,
            metadata: .init(from: encodedMetadata),
            participants: participants.sorted(by: { $0.userID < $1.userID }),
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

        guard let participantMap = data[Keys.participants.rawValue] as? [String: [String: Any]],
              participantMap.count > 1,
              encodedMessageRecipientConsentAcknowledgementData.count == encodedPenPalsSharingData.count,
              encodedPenPalsSharingData.count == participantMap.count,
              let encodedReactionMetadata = data[Keys.reactionMetadata.rawValue] as? [[String: Any]],
              encodedReactionMetadata.allSatisfy({ ReactionMetadata.canDecode(from: $0) }),
              data[Keys.messages.rawValue] is [String: Any] ||
              data[Keys.messages.rawValue] == nil else { return false }

        return true
    }
}
