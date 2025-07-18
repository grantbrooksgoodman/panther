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
    public let previousLanguageCodes: [String]?
    public let pushTokens: [String]?

    // NIT: Should be @LockIsolated, but would lose Codable conformance.
    public private(set) var conversationIDs: [ConversationID]?
    public private(set) var conversations: [Conversation]?

    // Bool
    public let isPenPalsParticipant: Bool
    public let messageRecipientConsentRequired: Bool

    // String
    public let id: String
    public let languageCode: String

    // Other
    public let phoneNumber: PhoneNumber

    private var isSettingConversations = false

    // MARK: - Computed Properties

    public var canSendAudioMessages: Bool {
        @Dependency(\.commonServices.audio.transcription) var transcriptionService: TranscriptionService
        return transcriptionService.isTranscriptionSupported(for: languageCode)
    }

    public var hostedBadgeNumber: Int {
        get async {
            @Dependency(\.networking.database) var database: DatabaseDelegate
            let getValuesResult = await database.getValues(
                at: "\(NetworkPath.users.rawValue)/\(id)/\(User.SerializationKeys.badgeNumber.rawValue)",
                cacheStrategy: .disregardCache
            )

            switch getValuesResult {
            case let .success(values):
                guard let integer = values as? Int else {
                    Logger.log(
                        .Networking.typecastFailed("integer", metadata: [self, #file, #function, #line]),
                        domain: .user
                    )
                    return 0
                }

                return integer

            case let .failure(exception):
                Logger.log(exception, domain: .user)
                return 0
            }
        }
    }

    // MARK: - Init

    public init(
        _ id: String,
        blockedUserIDs: [String]?,
        conversationIDs: [ConversationID]?,
        isPenPalsParticipant: Bool,
        languageCode: String,
        messageRecipientConsentRequired: Bool,
        phoneNumber: PhoneNumber,
        previousLanguageCodes: [String]?,
        pushTokens: [String]?
    ) {
        self.id = id
        self.blockedUserIDs = blockedUserIDs
        self.conversationIDs = conversationIDs
        self.isPenPalsParticipant = isPenPalsParticipant
        self.languageCode = languageCode
        self.messageRecipientConsentRequired = messageRecipientConsentRequired
        self.phoneNumber = phoneNumber
        self.previousLanguageCodes = previousLanguageCodes
        self.pushTokens = pushTokens
    }

    // MARK: - Badge Number Calculation

    /// - Note: Will return `0` for users other than the current user.
    public func calculateBadgeNumber(_ returnZeroIfFailedOnce: Bool = false) async -> Int {
        @Persistent(.currentUserID) var currentUserID: String?
        guard id == currentUserID else { return 0 }

        if conversationIDs?.isEmpty == false,
           conversations == nil || conversations?.isEmpty == true {
            guard !returnZeroIfFailedOnce else { return 0 }
            if let exception = await setConversations() {
                Logger.log(exception, domain: .user)
                return 0
            }

            guard let conversations,
                  !conversations.isEmpty else { return 0 }

            for conversation in conversations.visibleForCurrentUser.filter({ $0.messages == nil }) {
                if let exception = await conversation.setMessages() { Logger.log(exception, domain: .user) }
            }

            return await calculateBadgeNumber(true)
        }

        guard let conversations else { return 0 }
        return conversations
            .visibleForCurrentUser
            .compactMap(\.messages)
            .reduce([], +)
            .filter { !$0.isFromCurrentUser && $0.currentUserReadReceipt == nil }.count
    }

    // MARK: - Capability Testing

    public func canSendAudioMessages(to user: User) -> Bool {
        @Dependency(\.commonServices.audio.textToSpeech) var textToSpeechService: TextToSpeechService
        return canSendAudioMessages && textToSpeechService.isTextToSpeechSupported(for: user.languageCode)
    }

    // MARK: - Set Conversations

    /// - Note: Returns `nil` if called on a user other than the current user.
    public func setConversations() async -> Exception? {
        @Dependency(\.networking.conversationService) var conversationService: ConversationService
        @Dependency(\.clientSession.conversation) var conversationSession: ConversationSessionService
        @Dependency(\.coreKit.gcd.newSerialQueue) var serialQueue: DispatchQueue

        guard !isSettingConversations else {
            Logger.log(.init(
                "Detected extraneous call to User.setConversations().",
                isReportable: false,
                metadata: [self, #file, #function, #line]
            ))
            return nil
        }

        @Persistent(.currentUserID) var currentUserID: String?
        guard id == currentUserID,
              let conversationIDs else { return nil }

        isSettingConversations = true

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
                self.isSettingConversations = false
            }
            return nil
        }

        for conversation in conversationsNeedingUpdate {
            let synchronizeConversationResult = await conversationSession.sync.synchronizeConversation(conversation)

            switch synchronizeConversationResult {
            case let .success(updatedConversation):
                decodedConversations.removeAll(where: { $0.id.key == updatedConversation.id.key })
                decodedConversations.append(updatedConversation)

            case let .failure(exception):
                isSettingConversations = false
                return exception
            }
        }

        guard !conversationsNeedingFetch.isEmpty else {
            guard decodedConversations.count == conversationIDs.count else {
                isSettingConversations = false
                return .init("Mismatched ratio returned.", metadata: [self, #file, #function, #line])
            }

            // FIXME: Seeing data races using mainQueue.sync. Still occur with serialQueue.sync, but with less frequency. Can't use NSLock.
            serialQueue.sync {
                self.conversationIDs = decodedConversations.map(\.id)
                conversations = decodedConversations.sortedByLatestMessageSentDate
                decodedConversations.forEach { conversationService.archive.addValue($0) }
                self.isSettingConversations = false
            }
            return nil
        }

        let getConversationsResult = await conversationService.getConversations(idKeys: conversationsNeedingFetch.map(\.key))

        switch getConversationsResult {
        case let .success(conversations):
            decodedConversations.append(contentsOf: conversations)

            guard decodedConversations.count == conversationIDs.count else {
                isSettingConversations = false
                return .init("Mismatched ratio returned.", metadata: [self, #file, #function, #line])
            }

            // FIXME: Seeing data races using mainQueue.sync. Still occur with serialQueue.sync, but with less frequency. Can't use NSLock.
            serialQueue.sync {
                self.conversationIDs = decodedConversations.map(\.id)
                self.conversations = decodedConversations.sortedByLatestMessageSentDate
                decodedConversations.forEach { conversationService.archive.addValue($0) }
                self.isSettingConversations = false
            }
            return nil

        case let .failure(exception):
            isSettingConversations = false
            return exception
        }
    }

    // MARK: - Equatable Conformance

    public static func == (left: User, right: User) -> Bool {
        let sameBlockedUserIDs = left.blockedUserIDs == right.blockedUserIDs
        let sameConversationIDs = left.conversationIDs == right.conversationIDs
        let sameConversations = left.conversations == right.conversations
        let sameID = left.id == right.id
        let sameIsPenPalsParticipant = left.isPenPalsParticipant == right.isPenPalsParticipant
        let sameLanguageCode = left.languageCode == right.languageCode
        let sameMessageRecipientConsentRequired = left.messageRecipientConsentRequired == right.messageRecipientConsentRequired
        let samePhoneNumber = left.phoneNumber == right.phoneNumber
        let samePreviousLanguageCodes = left.previousLanguageCodes == right.previousLanguageCodes
        let samePushTokens = left.pushTokens == right.pushTokens

        guard sameBlockedUserIDs,
              sameConversationIDs,
              sameConversations,
              sameID,
              sameIsPenPalsParticipant,
              sameLanguageCode,
              sameMessageRecipientConsentRequired,
              samePhoneNumber,
              samePreviousLanguageCodes,
              samePushTokens else { return false }

        return true
    }
}
