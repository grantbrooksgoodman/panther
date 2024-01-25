//
//  User.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public final class User: Codable, Equatable {
    // MARK: - Properties

    // Array
    public let pushTokens: [String]?

    public private(set) var conversationIDs: [ConversationID]?
    public private(set) var conversations: [Conversation]?

    // String
    public let id: String
    public let languageCode: String

    // Other
    public let badgeNumber: Int
    public let phoneNumber: PhoneNumber

    // MARK: - Computed Properties

    public var canSendAudioMessages: Bool {
        @Dependency(\.commonServices.audio.transcription) var transcriptionService: TranscriptionService
        return transcriptionService.isTranscriptionSupported(for: languageCode)
    }

    // MARK: - Init

    public init(
        _ id: String,
        badgeNumber: Int,
        conversationIDs: [ConversationID]?,
        languageCode: String,
        phoneNumber: PhoneNumber,
        pushTokens: [String]?
    ) {
        self.id = id
        self.badgeNumber = badgeNumber
        self.conversationIDs = conversationIDs
        self.languageCode = languageCode
        self.phoneNumber = phoneNumber
        self.pushTokens = pushTokens
    }

    // MARK: - Methods

    public func canSendAudioMessages(to user: User) -> Bool {
        @Dependency(\.commonServices.audio.textToSpeech) var textToSpeechService: TextToSpeechService
        return canSendAudioMessages && textToSpeechService.isTextToSpeechSupported(for: user.languageCode)
    }

    public func setConversations() async -> Exception? {
        @Dependency(\.networking.services.conversation) var conversationService: ConversationService
        @Dependency(\.clientSessionService.conversation) var conversationSession: ConversationSessionService
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

    // MARK: - Equatable Conformance

    public static func == (left: User, right: User) -> Bool {
        let sameBadgeNumber = left.badgeNumber == right.badgeNumber
        let sameConversationIDs = left.conversationIDs == right.conversationIDs
        let sameConversations = left.conversations == right.conversations
        let sameID = left.id == right.id
        let sameLanguageCode = left.languageCode == right.languageCode
        let samePhoneNumber = left.phoneNumber == right.phoneNumber
        let samePushTokens = left.pushTokens == right.pushTokens

        guard sameBadgeNumber,
              sameConversationIDs,
              sameConversations,
              sameID,
              sameLanguageCode,
              samePhoneNumber,
              samePushTokens else { return false }

        return true
    }
}
