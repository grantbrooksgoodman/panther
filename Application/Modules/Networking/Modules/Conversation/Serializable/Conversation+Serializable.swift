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

extension Conversation: Serializable {
    // MARK: - Type Aliases

    public typealias T = Conversation
    private typealias Keys = SerializationKeys

    // MARK: - Types

    public enum SerializationKeys: String {
        case id
        case encodedHash = "hash"
        case messages
        case metadata
        case participants
    }

    // MARK: - Properties

    public var encoded: [String: Any] {
        let messageIDs = messages?.map(\.id) ?? .bangQualifiedEmpty
        return [
            Keys.id.rawValue: id.encoded,
            Keys.encodedHash.rawValue: encodedHash,
            Keys.messages.rawValue: messageIDs.isBangQualifiedEmpty ? .bangQualifiedEmpty : messageIDs,
            Keys.metadata.rawValue: metadata.encoded,
            Keys.participants.rawValue: participants.map(\.encoded),
        ]
    }

    // MARK: - Methods

    public static func canDecode(from data: [String: Any]) -> Bool {
        guard data[Keys.id.rawValue] as? String != nil,
              let encodedMetadata = data[Keys.metadata.rawValue] as? [String: Any],
              ConversationMetadata.canDecode(from: encodedMetadata),
              let encodedParticipants = data[Keys.participants.rawValue] as? [String],
              encodedParticipants.allSatisfy({ Participant.canDecode(from: $0) }),
              data[Keys.messages.rawValue] as? [String] != nil else { return false }

        return true
    }

    public static func decode(from data: [String: Any]) async -> Callback<Conversation, Exception> {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        @Dependency(\.networking.messageService) var messageService: MessageService

        guard let id = data[Keys.id.rawValue] as? String,
              let encodedMetadata = data[Keys.metadata.rawValue] as? [String: Any],
              let encodedParticipants = data[Keys.participants.rawValue] as? [String],
              let messageIDs = data[Keys.messages.rawValue] as? [String] else {
            return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
        }

        var conversationID: ConversationID?
        let decodeConversationIDResult = await ConversationID.decode(from: id)

        switch decodeConversationIDResult {
        case let .success(decodedConversationID):
            conversationID = decodedConversationID

        case let .failure(exception):
            return .failure(exception)
        }

        guard let conversationID else {
            return .failure(.init("Failed to decode conversation ID.", metadata: [self, #file, #function, #line]))
        }

        var metadata: ConversationMetadata?
        let decodeConversationMetadataResult = await ConversationMetadata.decode(from: encodedMetadata)

        switch decodeConversationMetadataResult {
        case let .success(decodedConversationMetadata):
            metadata = decodedConversationMetadata

        case let .failure(exception):
            return .failure(exception)
        }

        guard let metadata else {
            return .failure(.init("Failed to decode conversation metadata.", metadata: [self, #file, #function, #line]))
        }

        var participants = [Participant]()

        for encodedParticipant in encodedParticipants {
            let decodeResult = await Participant.decode(from: encodedParticipant)

            switch decodeResult {
            case let .success(participant):
                participants.append(participant)

            case let .failure(exception):
                return .failure(exception)
            }
        }

        guard !participants.isEmpty,
              participants.count == encodedParticipants.count else {
            return .failure(.init("Mismatched ratio returned.", metadata: [self, #file, #function, #line]))
        }

        guard let currentUserParticipant = participants.firstWithCurrentUserID,
              !currentUserParticipant.hasDeletedConversation else {
            let decoded: Conversation = .init(
                conversationID,
                messageIDs: messageIDs.isBangQualifiedEmpty ? .bangQualifiedEmpty : messageIDs,
                messages: nil,
                metadata: metadata,
                participants: participants,
                users: nil
            )

            Logger.log(
                .init(
                    "Skipping message retrieval for conversation in which current user is not participating or has deleted.",
                    extraParams: ["ConversationIDKey": conversationID.key,
                                  "ConversationIDHash": conversationID.hash],
                    metadata: [self, #file, #function, #line]
                ),
                domain: .conversation
            )

            return .success(decoded)
        }

        guard !messageIDs.isBangQualifiedEmpty else {
            let decoded: Conversation = .init(
                conversationID,
                messageIDs: .bangQualifiedEmpty,
                messages: .init(),
                metadata: metadata,
                participants: participants,
                users: nil
            )

            return .success(decoded)
        }

        let getMessagesResult = await messageService.getMessages(ids: messageIDs)

        switch getMessagesResult {
        case let .success(messages):
            guard !messages.isEmpty,
                  messages.count == messageIDs.count else {
                return .failure(.init("Mismatched ratio returned.", metadata: [self, #file, #function, #line]))
            }

            let decoded: Conversation = .init(
                conversationID,
                messageIDs: messageIDs,
                messages: messages.sorted(by: { $0.sentDate < $1.sentDate }),
                metadata: metadata,
                participants: participants,
                users: nil
            )

            return .success(decoded)

        case let .failure(exception):
            return .failure(exception)
        }
    }
}
