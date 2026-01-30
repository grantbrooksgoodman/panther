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

final class User: Codable, EncodedHashable, Equatable, Hashable {
    // MARK: - Properties

    // NIT: Should be @LockIsolated, but would lose Codable conformance.
    private(set) var conversationIDs: [ConversationID]?
    private(set) var conversations: [Conversation]?

    let aiEnhancedTranslationsEnabled: Bool
    let blockedUserIDs: [String]?
    let id: String
    let isPenPalsParticipant: Bool
    let languageCode: String
    let messageRecipientConsentRequired: Bool
    let phoneNumber: PhoneNumber
    let previousLanguageCodes: [String]?
    let pushTokens: [String]?

    // MARK: - Computed Properties

    var canSendAudioMessages: Bool {
        @Dependency(\.commonServices.audio.transcription) var transcriptionService: TranscriptionService
        return transcriptionService.isTranscriptionSupported(for: languageCode)
    }

    var hashFactors: [String] {
        var factors = [String]()
        factors.append(aiEnhancedTranslationsEnabled.description)
        factors.append(contentsOf: blockedUserIDs ?? [])
        factors.append(contentsOf: conversationIDs?.map(\.encoded) ?? [])
        factors.append(contentsOf: conversations?.map(\.encodedHash) ?? []) // TODO: Audit this.
        factors.append(id)
        factors.append(isPenPalsParticipant.description)
        factors.append(languageCode)
        factors.append(messageRecipientConsentRequired.description)
        factors.append(phoneNumber.encodedHash)
        factors.append(contentsOf: previousLanguageCodes ?? [])
        factors.append(contentsOf: pushTokens ?? [])
        return factors.sorted()
    }

    var hostedBadgeNumber: Int {
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
                        .Networking.typecastFailed("integer", metadata: .init(sender: self)),
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

    init(
        _ id: String,
        aiEnhancedTranslationsEnabled: Bool,
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
        self.aiEnhancedTranslationsEnabled = aiEnhancedTranslationsEnabled
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
    func calculateBadgeNumber(_ returnZeroIfFailedOnce: Bool = false) async -> Int {
        guard id == User.currentUserID else { return 0 }

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
                if let exception = await conversation.setMessages() {
                    Logger.log(exception, domain: .user)
                }
            }

            return await calculateBadgeNumber(true)
        }

        guard let conversations else { return 0 }
        return conversations
            .visibleForCurrentUser
            .flatMap { $0.messages ?? [] }
            .filteringSystemMessages
            .filter { !$0.isFromCurrentUser && $0.currentUserReadReceipt == nil }
            .count
    }

    // MARK: - Capability Testing

    func canSendAudioMessages(to user: User) -> Bool {
        @Dependency(\.commonServices.audio.textToSpeech) var textToSpeechService: TextToSpeechService
        return canSendAudioMessages && textToSpeechService.isTextToSpeechSupported(for: user.languageCode)
    }

    // MARK: - Set Conversations

    /// - Note: Returns `nil` if called on a user other than the current user.
    func setConversations() async -> Exception? {
        @Dependency(\.networking.conversationService) var conversationService: ConversationService
        @Dependency(\.clientSession.conversation) var conversationSession: ConversationSessionService
        @Dependency(\.coreKit.gcd.newSerialQueue) var serialQueue: DispatchQueue

        guard id == User.currentUserID,
              let conversationIDs else { return nil }

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
            sender: self
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
            let synchronizeConversationResult = await conversationSession.sync.synchronizeConversation(conversation)

            switch synchronizeConversationResult {
            case let .success(updatedConversation):
                decodedConversations.removeAll(where: { $0.id.key == updatedConversation.id.key })
                decodedConversations.append(updatedConversation)

            case let .failure(exception):
                return exception
            }
        }

        guard !conversationsNeedingFetch.isEmpty else {
            guard decodedConversations.count == conversationIDs.count else {
                return .init("Mismatched ratio returned.", metadata: .init(sender: self))
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
                return .init("Mismatched ratio returned.", metadata: .init(sender: self))
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

    static func == (left: User, right: User) -> Bool {
        left.encodedHash == right.encodedHash
    }

    // MARK: - Hashable Conformance

    func hash(into hasher: inout Hasher) {
        hasher.combine(encodedHash)
    }
}
