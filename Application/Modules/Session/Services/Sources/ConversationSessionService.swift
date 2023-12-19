//
//  ConversationSessionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public struct ConversationSessionService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.clientSessionService.user) private var userSession: UserSessionService

    // MARK: - Deletion

    public func deleteConversation(_ conversation: Conversation) async -> Exception? {
        guard conversation.participants.allSatisfy(\.hasDeletedConversation) else {
            guard let currentUser = userSession.currentUser else {
                return .init("No current user.", metadata: [self, #file, #function, #line])
            }

            return await hideConversation(conversation, forUserID: currentUser.id)
        }

        if let exception = await removeConversationFromUsers(
            userIDs: conversation.participants.map(\.userID),
            conversationIDKey: conversation.id.key
        ) {
            return exception
        }

        if let exception = await networking.services.message.deleteMessages(
            conversation.messages,
            in: conversation
        ) {
            return exception
        }

        let path = networking.config.paths.conversations
        if let exception = await networking.database.setValue(
            NSNull(),
            forKey: "\(path)/\(conversation.id.key)"
        ) {
            return exception
        }

        return nil
    }

    private func hideConversation(_ conversation: Conversation, forUserID userID: String) async -> Exception? {
        var newParticipants = conversation.participants.filter { $0.userID != userID }

        for participant in conversation.participants where !newParticipants.contains(participant) {
            let newParticipant: Participant = .init(
                userID: participant.userID,
                hasDeletedConversation: true,
                isTyping: participant.isTyping
            )
            newParticipants.append(newParticipant)
        }

        newParticipants = newParticipants.unique
        let encodedParticipants = newParticipants.map(\.encoded)

        let path = networking.config.paths.conversations
        if let exception = await networking.database.setValue(
            encodedParticipants,
            forKey: "\(path)/\(conversation.id.key)/\(Conversation.SerializationKeys.participants.rawValue)"
        ) {
            return exception
        }

        return nil
    }

    private func removeConversationFromUsers(userIDs: [String], conversationIDKey: String) async -> Exception? {
        func removeConversationFromUser(userID: String, conversationIDKey: String) async -> Exception? {
            let commonParams = ["UserID": userID, "ConversationID": conversationIDKey]

            guard !userID.isBangQualifiedEmpty,
                  !conversationIDKey.isBangQualifiedEmpty else {
                let exception = Exception("Passed arguments fail validation.", metadata: [self, #file, #function, #line])
                return exception.appending(extraParams: commonParams)
            }

            let getConversationIDStringsResult = await networking.services.conversation.getConversationIDStrings(for: userID)

            switch getConversationIDStringsResult {
            case var .success(conversationIDStrings):
                conversationIDStrings.removeAll(where: { $0.hasPrefix(conversationIDKey) })
                conversationIDStrings = conversationIDStrings.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : conversationIDStrings

                let path = networking.config.paths.users
                if let exception = await networking.database.setValue(
                    conversationIDStrings,
                    forKey: "\(path)/\(userID)/\(User.SerializationKeys.conversations.rawValue)"
                ) {
                    return exception.appending(extraParams: commonParams)
                }

            case let .failure(exception):
                return exception.appending(extraParams: commonParams)
            }

            return nil
        }

        for userID in userIDs {
            if let exception = await removeConversationFromUser(
                userID: userID,
                conversationIDKey: conversationIDKey
            ) {
                return exception
            }
        }

        return nil
    }
}
