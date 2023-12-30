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
        case compressedHash = "hash"
        case messages
        case lastModifiedDate = "lastModified"
        case participants
    }

    // MARK: - Properties

    public var encoded: [String: Any] {
        @Dependency(\.standardDateFormatter) var dateFormatter: DateFormatter
        let messageIDs = messages.map(\.id)
        return [
            Keys.id.rawValue: id.encoded,
            Keys.compressedHash.rawValue: id.hash,
            Keys.messages.rawValue: messageIDs.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : messageIDs,
            Keys.lastModifiedDate.rawValue: dateFormatter.string(from: lastModifiedDate),
            Keys.participants.rawValue: participants.map(\.encoded),
        ]
    }

    // MARK: - Methods

    public static func decode(from data: [String: Any]) async -> Callback<Conversation, Exception> {
        @Dependency(\.clientSessionService.conversation) var conversationSession: ConversationSessionService
        @Dependency(\.standardDateFormatter) var dateFormatter: DateFormatter
        @Dependency(\.networking.services) var networkServices: NetworkServices

        guard let id = data[Keys.id.rawValue] as? String,
              let messageIDs = data[Keys.messages.rawValue] as? [String],
              let lastModifiedDateString = data[Keys.lastModifiedDate.rawValue] as? String,
              let lastModifiedDate = dateFormatter.date(from: lastModifiedDateString),
              let encodedParticipants = data[Keys.participants.rawValue] as? [String] else {
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

        if let archivedConversation = networkServices.conversation.archive.getValue(id: conversationID) {
            Logger.log(
                .init(
                    "Successfully retrieved conversation from archive.",
                    extraParams: ["ConversationIDKey": conversationID.key,
                                  "ConversationIDHash": conversationID.hash],
                    metadata: [self, #file, #function, #line]
                )
            )

            return .success(archivedConversation)
        } else if let outdatedConversation = networkServices.conversation.archive.getValue(idKey: conversationID.key) {
            let updateConversationResult = await conversationSession.updateConversation(outdatedConversation)

            switch updateConversationResult {
            case let .success(conversation):
                networkServices.conversation.archive.addValue(conversation)
                return .success(conversation)

            case let .failure(exception):
                return .failure(exception)
            }
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

        guard !messageIDs.isBangQualifiedEmpty else {
            let decoded: Conversation = .init(
                conversationID,
                messages: .init(),
                lastModifiedDate: lastModifiedDate,
                participants: participants,
                users: nil
            )

            networkServices.conversation.archive.addValue(decoded)
            return .success(decoded)
        }

        let getMessagesResult = await networkServices.message.getMessages(ids: messageIDs)

        switch getMessagesResult {
        case let .success(messages):
            guard !messages.isEmpty,
                  messages.count == messageIDs.count else {
                return .failure(.init("Mismatched ratio returned.", metadata: [self, #file, #function, #line]))
            }

            let decoded: Conversation = .init(
                conversationID,
                messages: messages.sorted(by: { $0.sentDate < $1.sentDate }),
                lastModifiedDate: lastModifiedDate,
                participants: participants,
                users: nil
            )

            networkServices.conversation.archive.addValue(decoded)
            return .success(decoded)

        case let .failure(exception):
            return .failure(exception)
        }
    }
}
