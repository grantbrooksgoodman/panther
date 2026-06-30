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
    let id: String
    @Updatable let isPenPalsParticipant: Bool
    let languageCode: String
    @Updatable(nilIf: .custom("$0 == .init(timeIntervalSince1970: 0)")) let lastSignedIn: Date?
    @Updatable let messageRecipientConsentRequired: Bool
    let phoneNumber: PhoneNumber
    @Updatable(nilIf: .isBangQualifiedEmpty) let previousLanguageCodes: [String]?
    @Updatable(nilIf: .isBangQualifiedEmpty) let pushTokens: [String]?

    // NIT: Should be @LockIsolated, but would lose Codable conformance.
    @Updatable private(set) var conversationIDs: [ConversationID]?
    private(set) var conversations: [Conversation]?

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
        factors.append(contentsOf: conversations?.map(\.encodedHash) ?? [])
        factors.append(id)
        factors.append(isPenPalsParticipant.description)
        factors.append(languageCode)
        factors.append(Date.timestampFromOptional(date: lastSignedIn))
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
                Logger.log(
                    error,
                    domain: .user
                )

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
        lastSignedIn: Date?,
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
        self.lastSignedIn = lastSignedIn
        self.messageRecipientConsentRequired = messageRecipientConsentRequired
        self.phoneNumber = phoneNumber
        self.previousLanguageCodes = previousLanguageCodes
        self.pushTokens = pushTokens
    }

    // MARK: - Badge Number Calculation

    /// - Note: Will return `0` for users other than the current user.
    func calculateBadgeNumber() async -> Int {
        guard id == User.currentUserID else { return 0 }

        if conversationIDs?.isEmpty == false,
           conversations == nil || conversations?.isEmpty == true {
            @Dependency(\.clientSession.user) var userSession: UserSessionService
            do {
                try await userSession.hydrateCurrentUserConversations()
            } catch {
                Logger.log(
                    error,
                    domain: .user
                )
                return 0
            }

            guard let updatedConversations = userSession.currentUser?.conversations,
                  !updatedConversations.isEmpty else { return 0 }

            return updatedConversations
                .visibleForCurrentUser
                .flatMap { $0.messages ?? [] }
                .filteringSystemMessages
                .filter { !$0.isFromCurrentUser && $0.currentUserReadReceipt == nil }
                .count
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
        return canSendAudioMessages && textToSpeechService.isTextToSpeechSupported(
            for: user.languageCode
        )
    }

    // MARK: - Inheriting Local State

    /// Returns a copy of this user with `conversations` populated from a previous instance.
    ///
    /// When `resolveCurrentUser()` creates a new `User` value, `conversations` is `nil`
    /// because it's populated locally (not from the server). This method carries over
    /// the prior instance's `conversations` to avoid redundant hydration calls.
    func inheritingLocalState(from user: User?) -> User {
        guard let user,
              user.id == id,
              conversations == nil || conversations?.isEmpty == true,
              let sourceConversations = user.conversations,
              !sourceConversations.isEmpty else { return self }
        Logger.log(
            "Inherited local state from previous user instance.",
            domain: .user,
            sender: self
        )

        var result = self
        result.conversations = sourceConversations
        return result
    }

    // MARK: - Setting Conversations

    /// Returns a copy of this user with `conversations` and `conversationIDs` populated.
    ///
    /// - Note: Does nothing if called on a user other than the current user.
    func settingConversations(
        _ conversations: Set<Conversation>
    ) -> User {
        var result = self
        result.conversationIDs = conversations.map(\.id)
        result.conversations = Array(conversations).sortedByLatestMessageSentDate
        return result
    }

    // MARK: - Equatable Conformance

    static func == (
        left: User,
        right: User
    ) -> Bool {
        left.encodedHash == right.encodedHash
    }

    // MARK: - Hashable Conformance

    func hash(into hasher: inout Hasher) {
        hasher.combine(encodedHash)
    }
}
