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

@RemotelyUpdatable
struct User: Codable, EncodedHashable, Hashable {
    // MARK: - Properties

    @Updatable let aiEnhancedTranslationsEnabled: Bool
    @Updatable(nilIf: .isBangQualifiedEmpty) let blockedUserIDs: [String]?
    @Updatable let conversationIDs: [ConversationID]?
    @Updatable let deviceID: String
    let id: String
    @Updatable let isPenPalsParticipant: Bool
    @Updatable let languageCode: String
    @Updatable let messageRecipientConsentRequired: Bool
    let phoneNumber: PhoneNumber
    @Updatable(nilIf: .isBangQualifiedEmpty) let previousLanguageCodes: [String]?
    @Updatable(nilIf: .isBangQualifiedEmpty) let pushTokens: [String]?

    // MARK: - Computed Properties

    var canSendAudioMessages: Bool {
        @Dependency(\.commonServices.audio.transcription) var transcriptionService: TranscriptionService
        return transcriptionService.isTranscriptionSupported(for: languageCode)
    }

    /// Resolves conversations from the session store using this user's `conversationIDs`.
    var conversations: [Conversation]? {
        @Dependency(\.clientSession.store) var sessionStore: SessionStore
        guard let conversationIDs else { return nil }
        let conversations = conversationIDs.compactMap { sessionStore.conversations[$0.key] }
        guard conversations.count == conversationIDs.count else { return nil }
        return conversations.isEmpty ? nil : conversations
    }

    var hashFactors: [String] {
        var factors = [String]()
        factors.append(aiEnhancedTranslationsEnabled.description)
        factors.append(contentsOf: blockedUserIDs ?? [])
        factors.append(contentsOf: conversationIDs?.map(\.encoded) ?? [])
        factors.append(deviceID)
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
            do {
                @Dependency(\.networking.database) var database: DatabaseDelegate
                return try await database.getValues(
                    at: [
                        NetworkPath.users.rawValue,
                        id,
                        User.SerializableKey.badgeNumber.rawValue,
                    ].joined(separator: "/"),
                    cacheStrategy: .disregardCache
                )
            } catch {
                Logger.log(error)
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
        deviceID: String,
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
        self.deviceID = deviceID
        self.isPenPalsParticipant = isPenPalsParticipant
        self.languageCode = languageCode
        self.messageRecipientConsentRequired = messageRecipientConsentRequired
        self.phoneNumber = phoneNumber
        self.previousLanguageCodes = previousLanguageCodes
        self.pushTokens = pushTokens
    }

    // MARK: - Badge Number Calculation

    /// - Note: Will return `0` for users other than the current user.
    func calculateBadgeNumber() -> Int {
        guard id == User.currentUserID,
              let conversations else { return 0 }
        return conversations
            .visibleForCurrentUser
            .flatMap { $0.messages ?? [] }
            .filter { !$0.isFromCurrentUser && $0.currentUserReadReceipt == nil }
            .count
    }

    // MARK: - Capability Testing

    func canSendAudioMessages(to user: User) -> Bool {
        @Dependency(\.commonServices.audio.textToSpeech) var textToSpeechService: TextToSpeechService
        return canSendAudioMessages && textToSpeechService.isTextToSpeechSupported(
            for: user.languageCode
        )
    }

    // MARK: - Hashable Conformance

    func hash(into hasher: inout Hasher) {
        hasher.combine(encodedHash)
    }
}
