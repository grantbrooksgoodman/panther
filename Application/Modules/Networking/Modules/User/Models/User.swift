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

    // PhoneNumber
    public let phoneNumber: PhoneNumber

    // String
    public let id: String
    public let languageCode: String

    // MARK: - Computed Properties

    public var canSendAudioMessages: Bool {
        @Dependency(\.commonServices.audio.transcription) var transcriptionService: TranscriptionService
        return transcriptionService.isTranscriptionSupported(for: languageCode)
    }

    // MARK: - Init

    public init(
        _ id: String,
        conversationIDs: [ConversationID]?,
        languageCode: String,
        phoneNumber: PhoneNumber,
        pushTokens: [String]?
    ) {
        self.id = id
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

    // TODO: This is expensive. Prefer a value on the user itself.
    public func getBadgeNumber() async -> Callback<Int, Exception> {
        var badgeNumber = 0

        guard let conversationIDs,
              !conversationIDs.isEmpty else {
            return .success(badgeNumber)
        }

        guard let conversations else {
            if let exception = await setConversations() {
                return .failure(exception)
            }

            return await getBadgeNumber()
        }

        guard conversations.allSatisfy({ $0.messages != nil }) else {
            if let exception = await conversations.setMessages() {
                return .failure(exception)
            }

            return await getBadgeNumber()
        }

        func incrementForUnread(_ messages: [Message]) {
            for message in messages where message.readDate == nil {
                badgeNumber += 1
            }
        }

        for conversation in conversations {
            guard let messages = conversation.messages else { continue }

            guard let lastMessageFromCurrentUser = messages.last(where: { $0.fromAccountID == id }),
                  let index = messages.firstIndex(of: lastMessageFromCurrentUser) else {
                incrementForUnread(messages)
                continue
            }

            guard messages.count > index else { continue }
            incrementForUnread(messages[index ... messages.count - 1].filter { $0.fromAccountID != id })
        }

        return .success(badgeNumber)
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
            // FIXME: Still seeing data races using mainQueue.sync. Trying CoreKit.GCD.newSerialQueue instead.
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

            // FIXME: Still seeing data races using mainQueue.sync. Trying CoreKit.GCD.newSerialQueue instead.
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

            // FIXME: Still seeing data races using mainQueue.sync. Trying CoreKit.GCD.newSerialQueue instead.
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
        let sameConversationIDs = left.conversationIDs == right.conversationIDs
        let sameConversations = left.conversations == right.conversations
        let sameID = left.id == right.id
        let sameLanguageCode = left.languageCode == right.languageCode
        let samePhoneNumber = left.phoneNumber == right.phoneNumber
        let samePushTokens = left.pushTokens == right.pushTokens

        guard sameConversationIDs,
              sameConversations,
              sameID,
              sameLanguageCode,
              samePhoneNumber,
              samePushTokens else { return false }

        return true
    }
}
