//
//  User.swift
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

public final class User: Codable, Equatable {
    // MARK: - Properties

    // Array
    public let blockedUserIDs: [String]?
    public let pushTokens: [String]?

    public private(set) var conversationIDs: [ConversationID]?
    public private(set) var conversations: [Conversation]?

    // String
    public let id: String
    public let languageCode: String

    // Other
    public let phoneNumber: PhoneNumber

    // MARK: - Computed Properties

    public var canSendAudioMessages: Bool {
        @Dependency(\.commonServices.audio.transcription) var transcriptionService: TranscriptionService
        return transcriptionService.isTranscriptionSupported(for: languageCode)
    }

    public var hostedBadgeNumber: Int {
        get async {
            @Dependency(\.networking.database) var database: DatabaseDelegate
            let getValuesResult = await database.getValues(at: "\(NetworkPath.users.rawValue)/\(id)/\(User.SerializationKeys.badgeNumber.rawValue)")

            switch getValuesResult {
            case let .success(values):
                guard let integer = values as? Int else {
                    Logger.log(.typecastFailed("integer", metadata: [self, #file, #function, #line]))
                    return 0
                }

                return integer

            case let .failure(exception):
                Logger.log(exception)
                return 0
            }
        }
    }

    // MARK: - Init

    public init(
        _ id: String,
        blockedUserIDs: [String]?,
        conversationIDs: [ConversationID]?,
        languageCode: String,
        phoneNumber: PhoneNumber,
        pushTokens: [String]?
    ) {
        self.id = id
        self.blockedUserIDs = blockedUserIDs
        self.conversationIDs = conversationIDs
        self.languageCode = languageCode
        self.phoneNumber = phoneNumber
        self.pushTokens = pushTokens
    }

    // MARK: - Badge Number Calculation

    /// - Note: Will return `0` for users other than the current user.
    public func calculateBadgeNumber() async -> Int {
        @Persistent(.currentUserID) var currentUserID: String?
        guard id == currentUserID,
              let conversationIDs,
              !conversationIDs.isEmpty else { return 0 }

        guard let conversations = conversations?.visibleForCurrentUser,
              conversations.allSatisfy({ $0.messages != nil }) else {
            _ = await conversations?.visibleForCurrentUser.setMessages()
            return await calculateBadgeNumber()
        }

        return conversations.compactMap(\.messages).reduce([], +).filter { !$0.isFromCurrentUser && $0.readDate == nil }.count
    }

    // MARK: - Capability Testing

    public func canSendAudioMessages(to user: User) -> Bool {
        @Dependency(\.commonServices.audio.textToSpeech) var textToSpeechService: TextToSpeechService
        return canSendAudioMessages && textToSpeechService.isTextToSpeechSupported(for: user.languageCode)
    }

    // MARK: - Set Conversations

    public func setConversations() async -> Exception? {
        @Dependency(\.networking.conversationService) var conversationService: ConversationService
        @Dependency(\.clientSession.conversation) var conversationSession: ConversationSessionService
        @Dependency(\.coreKit.gcd.newSerialQueue) var serialQueue: DispatchQueue

        guard let conversationIDs else { return nil }

        var conversationsNeedingFetch = [ConversationID]()
        var conversationsNeedingUpdate = [Conversation]()
        var decodedConversations = [Conversation]()

        for conversationID in conversationIDs {
            if let value = conversationService.archive.getValue(id: conversationID) {
                decodedConversations.append(value)
            } else if let value = conversationService.archive.getValue(idKey: conversationID.key) {
                conversationsNeedingUpdate.append(value)
            } else {
                conversationsNeedingFetch.append(conversationID)
            }
        }

        Logger.log(
            // swiftlint:disable:next line_length
            "Conversations needing update: \(conversationsNeedingUpdate.count)\nConversations needing fetch: \(conversationsNeedingFetch.count)\nDecoded conversations: \(decodedConversations.count)",
            domain: .user,
            metadata: [self, #file, #function, #line]
        )

        if conversationsNeedingFetch.isEmpty,
           conversationsNeedingUpdate.isEmpty {
            // FIXME: Seeing data races using mainQueue.sync. Still occur with serialQueue.sync, but with less frequency. Can't use NSLock.
            serialQueue.sync {
                self.conversationIDs = decodedConversations.map(\.id)
                conversations = decodedConversations.sortedByLatestMessageSentDate
                decodedConversations.forEach { conversationService.archive.addValue($0) }
            }
            return nil
        }

        for conversation in conversationsNeedingUpdate {
            let updateConversationResult = await conversationSession.updateConversation(conversation)

            switch updateConversationResult {
            case let .success(updatedConversation):
                decodedConversations.removeAll(where: { $0.id.key == updatedConversation.id.key })
                decodedConversations.append(updatedConversation)

            case let .failure(exception):
                return exception
            }
        }

        guard !conversationsNeedingFetch.isEmpty else {
            guard decodedConversations.count == conversationIDs.count else {
                return .init("Mismatched ratio returned.", metadata: [self, #file, #function, #line])
            }

            // FIXME: Seeing data races using mainQueue.sync. Still occur with serialQueue.sync, but with less frequency. Can't use NSLock.
            serialQueue.sync {
                self.conversationIDs = decodedConversations.map(\.id)
                conversations = decodedConversations.sortedByLatestMessageSentDate
                decodedConversations.forEach { conversationService.archive.addValue($0) }
            }
            return nil
        }

        let getConversationsResult = await conversationService.getConversations(idKeys: conversationsNeedingFetch.map(\.key))

        switch getConversationsResult {
        case let .success(conversations):
            decodedConversations.append(contentsOf: conversations)

            guard decodedConversations.count == conversationIDs.count else {
                return .init("Mismatched ratio returned.", metadata: [self, #file, #function, #line])
            }

            // FIXME: Seeing data races using mainQueue.sync. Still occur with serialQueue.sync, but with less frequency. Can't use NSLock.
            serialQueue.sync {
                self.conversationIDs = decodedConversations.map(\.id)
                self.conversations = decodedConversations.sortedByLatestMessageSentDate
                decodedConversations.forEach { conversationService.archive.addValue($0) }
            }
            return nil

        case let .failure(exception):
            return exception
        }
    }

    // MARK: - Update Hosted Badge Number

    public func updateHostedBadgeNumber(_ badgeNumber: Int? = nil) async -> Exception? {
        @Dependency(\.clientSession) var clientSession: ClientSession
        @Dependency(\.networking.database) var database: DatabaseDelegate

        @Persistent(.currentUserID) var currentUserID: String?
        switch id == currentUserID {
        case true:
            var newBadgeNumber = badgeNumber
            if newBadgeNumber == nil {
                newBadgeNumber = await calculateBadgeNumber()
            }

            guard let newBadgeNumber else {
                return .init(
                    "Failed to resolve badge number.",
                    metadata: [self, #file, #function, #line]
                )
            }

            return await database.setValue(
                newBadgeNumber,
                forKey: "\(NetworkPath.users.rawValue)/\(id)/\(User.SerializationKeys.badgeNumber.rawValue)"
            )

        case false:
            guard let badgeNumber else {
                return .init(
                    "Must supply badge number for users other than current user.",
                    metadata: [self, #file, #function, #line]
                )
            }

            return await database.setValue(
                badgeNumber,
                forKey: "\(NetworkPath.users.rawValue)/\(id)/\(User.SerializationKeys.badgeNumber.rawValue)"
            )
        }
    }

    // MARK: - Equatable Conformance

    public static func == (left: User, right: User) -> Bool {
        let sameBlockedUserIDs = left.blockedUserIDs == right.blockedUserIDs
        let sameConversationIDs = left.conversationIDs == right.conversationIDs
        let sameConversations = left.conversations == right.conversations
        let sameID = left.id == right.id
        let sameLanguageCode = left.languageCode == right.languageCode
        let samePhoneNumber = left.phoneNumber == right.phoneNumber
        let samePushTokens = left.pushTokens == right.pushTokens

        guard sameBlockedUserIDs,
              sameConversationIDs,
              sameConversations,
              sameID,
              sameLanguageCode,
              samePhoneNumber,
              samePushTokens else { return false }

        return true
    }
}
