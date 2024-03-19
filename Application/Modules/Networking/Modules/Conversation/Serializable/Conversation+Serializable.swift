//
//  Conversation+Serializable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

extension Conversation: Serializable {
    // MARK: - Type Aliases

    public typealias T = Conversation
    private typealias Keys = SerializationKeys

    // MARK: - Types

    public enum SerializationKeys: String {
        case id
        case encodedHash = "hash"
        case messages
        case name
        case lastModifiedDate = "lastModified"
        case participants
    }

    // MARK: - Properties

    public var encoded: [String: Any] {
        @Dependency(\.standardDateFormatter) var dateFormatter: DateFormatter
        let messageIDs = messages?.map(\.id) ?? .bangQualifiedEmpty
        return [
            Keys.id.rawValue: id.encoded,
            Keys.encodedHash.rawValue: encodedHash,
            Keys.messages.rawValue: messageIDs.isBangQualifiedEmpty ? .bangQualifiedEmpty : messageIDs,
            Keys.name.rawValue: name,
            Keys.lastModifiedDate.rawValue: dateFormatter.string(from: lastModifiedDate),
            Keys.participants.rawValue: participants.map(\.encoded),
        ]
    }

    // MARK: - Methods

    public static func decode(from data: [String: Any]) async -> Callback<Conversation, Exception> {
        @Dependency(\.standardDateFormatter) var dateFormatter: DateFormatter
        @Dependency(\.networking.services.message) var messageService: MessageService

        guard let id = data[Keys.id.rawValue] as? String,
              let encodedParticipants = data[Keys.participants.rawValue] as? [String],
              let messageIDs = data[Keys.messages.rawValue] as? [String],
              let name = data[Keys.name.rawValue] as? String,
              let lastModifiedDateString = data[Keys.lastModifiedDate.rawValue] as? String,
              let lastModifiedDate = dateFormatter.date(from: lastModifiedDateString) else {
            return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
        }

        var conversationID: ConversationID?
        let decodeResult = await ConversationID.decode(from: id)

        switch decodeResult {
        case let .success(decodedConversationID):
            conversationID = decodedConversationID

        case let .failure(exception):
            return .failure(exception)
        }

        guard let conversationID else {
            return .failure(.init("Failed to decode conversation ID.", metadata: [self, #file, #function, #line]))
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

        @Persistent(.currentUserID) var currentUserID: String?
        guard let currentUserParticipant = participants.first(where: { $0.userID == currentUserID }),
              !currentUserParticipant.hasDeletedConversation else {
            let decoded: Conversation = .init(
                conversationID,
                messageIDs: messageIDs,
                messages: nil,
                name: name,
                lastModifiedDate: lastModifiedDate,
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
                messageIDs: messageIDs.isBangQualifiedEmpty ? .bangQualifiedEmpty : messageIDs,
                messages: .init(),
                name: name,
                lastModifiedDate: lastModifiedDate,
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
                name: name,
                lastModifiedDate: lastModifiedDate,
                participants: participants,
                users: nil
            )

            return .success(decoded)

        case let .failure(exception):
            return .failure(exception)
        }
    }
}
