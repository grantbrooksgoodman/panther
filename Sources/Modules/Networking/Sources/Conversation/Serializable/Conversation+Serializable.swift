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

    public typealias T = Conversation
    private typealias Keys = SerializationKeys

    // MARK: - Types

    public enum SerializationKeys: String {
        case id
        case activities
        case encodedHash = "hash"
        case messages
        case metadata
        case participants
        case reactionMetadata
    }

    // MARK: - Properties

    public var encoded: [String: Any] {
        let messageIDs = messages?.map(\.id) ?? .bangQualifiedEmpty
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

    // MARK: - Methods

    public static func canDecode(from data: [String: Any]) -> Bool {
        guard data[Keys.id.rawValue] is String,
              let encodedActivities = data[Keys.activities.rawValue] as? [[String: Any]],
              encodedActivities.allSatisfy({ Activity.canDecode(from: $0) }),
              let encodedMetadata = data[Keys.metadata.rawValue] as? [String: Any],
              ConversationMetadata.canDecode(from: encodedMetadata), // swiftlint:disable:next identifier_name
              let encodedMessageRecipientConsentAcknowledgementData = encodedMetadata[
                  ConversationMetadata
                      .SerializationKeys
                      .messageRecipientConsentAcknowledgementData
                      .rawValue
              ] as? [String],
              let encodedPenPalsSharingData = encodedMetadata[
                  ConversationMetadata
                      .SerializationKeys
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

    // swiftlint:disable:next function_body_length
    public static func decode(from data: [String: Any]) async -> Callback<Conversation, Exception> {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        @Dependency(\.networking.messageService) var messageService: MessageService

        // Deserialize raw data

        guard let id = data[Keys.id.rawValue] as? String,
              let encodedActivities = data[Keys.activities.rawValue] as? [[String: Any]],
              let encodedMetadata = data[Keys.metadata.rawValue] as? [String: Any],
              let encodedParticipants = data[Keys.participants.rawValue] as? [String],
              let encodedReactionMetadata = data[Keys.reactionMetadata.rawValue] as? [[String: Any]],
              let messageIDs = data[Keys.messages.rawValue] as? [String] else {
            return .failure(.Networking.decodingFailed(data: data, .init(sender: self)))
        }

        // Decode conversation ID

        var conversationID: ConversationID?
        let decodeConversationIDResult = await ConversationID.decode(from: id)
        switch decodeConversationIDResult {
        case let .success(decodedConversationID): conversationID = decodedConversationID
        case let .failure(exception): return .failure(exception)
        }

        guard let conversationID else {
            return .failure(.init(
                "Failed to decode conversation ID.",
                metadata: .init(sender: self)
            ))
        }

        // Decode activities

        var activities = [Activity]()
        for encodedActivity in encodedActivities {
            let decodeResult = await Activity.decode(from: encodedActivity)
            switch decodeResult {
            case let .success(activity): activities.append(activity)
            case let .failure(exception): return .failure(exception)
            }
        }

        guard !activities.isEmpty,
              activities.count == encodedActivities.count else {
            return .failure(.init(
                "Mismatched ratio returned.",
                metadata: .init(sender: self)
            ))
        }

        // Decode metadata

        var metadata: ConversationMetadata?
        let decodeConversationMetadataResult = await ConversationMetadata.decode(from: encodedMetadata)
        switch decodeConversationMetadataResult {
        case let .success(decodedConversationMetadata): metadata = decodedConversationMetadata
        case let .failure(exception): return .failure(exception)
        }

        guard let metadata else {
            return .failure(.init(
                "Failed to decode conversation metadata.",
                metadata: .init(sender: self)
            ))
        }

        // Decode participants

        var participants = [Participant]()
        for encodedParticipant in encodedParticipants {
            let decodeResult = await Participant.decode(from: encodedParticipant)
            switch decodeResult {
            case let .success(participant): participants.append(participant)
            case let .failure(exception): return .failure(exception)
            }
        }

        guard !participants.isEmpty,
              participants.count == encodedParticipants.count else {
            return .failure(.init(
                "Mismatched ratio returned.",
                metadata: .init(sender: self)
            ))
        }

        // Decode reaction metadata

        var reactionMetadata = [ReactionMetadata]()
        for metadata in encodedReactionMetadata {
            let decodeReactionMetadataResult = await ReactionMetadata.decode(from: metadata)
            switch decodeReactionMetadataResult {
            case let .success(decodedReactionMetadata): reactionMetadata.append(decodedReactionMetadata)
            case let .failure(exception): return .failure(exception)
            }
        }

        guard !reactionMetadata.isEmpty,
              reactionMetadata.count == encodedReactionMetadata.count else {
            return .failure(.init(
                "Mismatched ratio returned.",
                metadata: .init(sender: self)
            ))
        }

        // Synthesize conversation

        guard let currentUserParticipant = participants.firstWithCurrentUserID,
              !currentUserParticipant.hasDeletedConversation else {
            let decoded: Conversation = .init(
                conversationID,
                activities: activities,
                messageIDs: messageIDs.isBangQualifiedEmpty ? .bangQualifiedEmpty : messageIDs,
                messages: nil,
                metadata: metadata,
                participants: participants,
                reactionMetadata: reactionMetadata.allSatisfy { $0 == .empty } ? nil : reactionMetadata,
                users: nil
            )

            Logger.log(
                .init(
                    "Skipping message retrieval for conversation in which current user is not participating or has deleted.",
                    isReportable: false,
                    userInfo: ["ConversationIDKey": conversationID.key,
                               "ConversationIDHash": conversationID.hash],
                    metadata: .init(sender: self)
                ),
                domain: .conversation
            )

            return .success(decoded)
        }

        guard !messageIDs.isBangQualifiedEmpty else {
            let decoded: Conversation = .init(
                conversationID,
                activities: activities,
                messageIDs: .bangQualifiedEmpty,
                messages: .init(),
                metadata: metadata,
                participants: participants,
                reactionMetadata: reactionMetadata.allSatisfy { $0 == .empty } ? nil : reactionMetadata,
                users: nil
            )

            return .success(decoded)
        }

        let getMessagesResult = await messageService.getMessages(ids: messageIDs)

        switch getMessagesResult {
        case let .success(messages):
            guard !messages.isEmpty,
                  messages.count == messageIDs.count else {
                return .failure(.init("Mismatched ratio returned.", metadata: .init(sender: self)))
            }

            let decoded: Conversation = .init(
                conversationID,
                activities: activities,
                messageIDs: messageIDs,
                messages: messages.hydrated(with: activities),
                metadata: metadata,
                participants: participants,
                reactionMetadata: reactionMetadata.allSatisfy { $0 == .empty } ? nil : reactionMetadata,
                users: nil
            )

            return .success(decoded)

        case let .failure(exception):
            return .failure(exception)
        }
    }
}
