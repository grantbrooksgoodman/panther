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

/// A registered user.
///
/// A user carries their identity, phone number, language, and preferences, along with the
/// identifiers of their conversations, blocked users, and push tokens. Values may be updated
/// individually and written to the remote database.
@RemotelyUpdatable
struct User: Codable, EncodedHashable, Hashable {
    // MARK: - Properties

    /// A Boolean value that indicates whether the user has enabled AI-enhanced translations.
    @Updatable let aiEnhancedTranslationsEnabled: Bool

    /// The identifiers of the users this user has blocked, or `nil` if none.
    @Updatable(nilIf: .isBangQualifiedEmpty) let blockedUserIDs: [String]?

    /// The identifiers of the user's conversations, or `nil` if none.
    @Updatable let conversationIDs: [ConversationID]?

    /// The identifier of the user's device.
    @Updatable let deviceID: String

    /// The user's unique identifier.
    let id: String

    /// A Boolean value that indicates whether the user participates in PenPals.
    @Updatable let isPenPalsParticipant: Bool

    /// The user's language code.
    @Updatable let languageCode: String

    /// A Boolean value that indicates whether the user requires message-receipt consent before
    /// receiving messages.
    @Updatable let messageRecipientConsentRequired: Bool

    /// The user's phone number.
    let phoneNumber: PhoneNumber

    /// The user's previously-used language codes, or `nil` if none.
    @Updatable(nilIf: .isBangQualifiedEmpty) let previousLanguageCodes: [String]?

    /// The user's push notification tokens, or `nil` if none.
    @Updatable(nilIf: .isBangQualifiedEmpty) let pushTokens: [String]?

    // MARK: - Computed Properties

    /// A Boolean value that indicates whether the user can send audio messages, based on
    /// transcription support for their language.
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

    /// The strings that collectively define this instance's identity for hashing purposes, sorted
    /// alphabetically.
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

    /// The user's application badge number, as stored in the remote database.
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

    /// Creates a user with the given properties.
    ///
    /// - Parameters:
    ///   - id: The user's unique identifier.
    ///   - aiEnhancedTranslationsEnabled: Whether the user has enabled AI-enhanced translations.
    ///   - blockedUserIDs: The identifiers of the users this user has blocked, or `nil` if none.
    ///   - conversationIDs: The identifiers of the user's conversations, or `nil` if none.
    ///   - deviceID: The identifier of the user's device.
    ///   - isPenPalsParticipant: Whether the user participates in PenPals.
    ///   - languageCode: The user's language code.
    ///   - messageRecipientConsentRequired: Whether the user requires message-receipt consent.
    ///   - phoneNumber: The user's phone number.
    ///   - previousLanguageCodes: The user's previously-used language codes, or `nil` if none.
    ///   - pushTokens: The user's push notification tokens, or `nil` if none.
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

    /// Returns the number of unread incoming messages across the user's visible conversations.
    ///
    /// - Returns: The unread message count, or `0` for users other than the current user.
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

    /// Returns a Boolean value that indicates whether this user can send audio messages to the
    /// given user, based on text-to-speech support for the recipient's language.
    ///
    /// - Parameter user: The recipient to query.
    ///
    /// - Returns: `true` if this user can send audio messages to the given user; otherwise,
    ///   `false`.
    func canSendAudioMessages(to user: User) -> Bool {
        @Dependency(\.commonServices.audio.textToSpeech) var textToSpeechService: TextToSpeechService
        return canSendAudioMessages && textToSpeechService.isTextToSpeechSupported(
            for: user.languageCode
        )
    }

    // MARK: - Hashable Conformance

    /// Hashes the user's ``encodedHash``.
    func hash(into hasher: inout Hasher) {
        hasher.combine(encodedHash)
    }
}
