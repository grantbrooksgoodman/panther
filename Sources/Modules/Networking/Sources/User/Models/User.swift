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

final class User: Codable, EncodedHashable, Hashable, @unchecked Sendable {
    // MARK: - Properties

    let aiEnhancedTranslationsEnabled: Bool
    let blockedUserIDs: [String]?
    let id: String
    let isPenPalsParticipant: Bool
    let languageCode: String
    let lastSignedIn: Date?
    let messageRecipientConsentRequired: Bool
    let phoneNumber: PhoneNumber
    let previousLanguageCodes: [String]?
    let pushTokens: [String]?

    // NIT: Should be @LockIsolated, but would lose Codable conformance.
    private(set) var conversationIDs: [ConversationID]?
    private(set) var conversations: [Conversation]?

    private static let coalescer = SingleSlotCoalescer<Exception?>()

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

            for conversation in conversations
                .visibleForCurrentUser
                .filter({
                    $0.messages == nil ||
                        $0.messages?.isEmpty == true ||
                        $0.filteringSystemMessages.messages?.count != $0.filteringSystemMessages.messageIDs.count
                }) {
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
        await Self.coalescer(
            mode: .lastCallerWins
        ) { [weak self] in
            guard let self else {
                return .init(
                    "User has been deallocated.",
                    metadata: .init(sender: User.self)
                )
            }

            return await _setConversations()
        }
    }

    private func _setConversations() async -> Exception? {
        @Dependency(\.networking.conversationService) var conversationService: ConversationService

        guard !Task.isCancelled,
              id == User.currentUserID,
              var conversationIDs else { return nil }

        var conversationsNeedingFetch = Set<ConversationID>()
        var conversationsNeedingUpdate = Set<Conversation>()
        var decodedConversations = Set<Conversation>()

        @Persistent(.conversationArchive) var conversationArchive: Set<Conversation>?
        let ignoredConversations = conversationArchive?
            .filter { !$0.isVisibleForCurrentUser }
            .map(\.id.key) ?? []
        conversationIDs = conversationIDs.filter { !ignoredConversations.contains($0.key) }

        for conversationID in conversationIDs {
            guard !Task.isCancelled else { return nil }
            if let value = conversationService.archive.getValue(id: conversationID) {
                decodedConversations.merge(with: [value])
            } else if let value = conversationService.archive.getValue(idKey: conversationID.key) {
                conversationsNeedingUpdate.insert(value)
            } else {
                conversationsNeedingFetch.insert(conversationID)
            }
        }

        guard !Task.isCancelled else { return nil }
        Logger.log(
            // swiftlint:disable:next line_length
            "Conversations needing update: \(conversationsNeedingUpdate.count)\nConversations needing fetch: \(conversationsNeedingFetch.count)\nIgnored conversations: \(ignoredConversations.count)\nDecoded conversations: \(decodedConversations.count)",
            domain: .user,
            sender: self
        )

        if conversationsNeedingFetch.isEmpty,
           conversationsNeedingUpdate.isEmpty {
            await commitToMemory(decodedConversations)
            return nil
        }

        let synchronizeResult = await conversationsNeedingUpdate.parallelMap {
            @Dependency(\.clientSession.conversation.sync) var conversationSyncService: ConversationSyncService
            return await conversationSyncService.synchronizeConversation($0)
        }

        guard !Task.isCancelled else { return nil }
        switch synchronizeResult {
        case let .success(synchronizedConversations):
            decodedConversations.merge(with: synchronizedConversations)

        case let .failure(exception):
            return exception
        }

        guard !conversationsNeedingFetch.isEmpty else {
            if let exception = validateRatio(
                decodedConversations,
                conversationIDs
            ) {
                return exception
            }

            await commitToMemory(decodedConversations)
            return nil
        }

        guard !Task.isCancelled else { return nil }
        let getConversationsResult = await conversationService.getConversations(
            idKeys: conversationsNeedingFetch.map(\.key)
        )

        switch getConversationsResult {
        case let .success(conversations):
            decodedConversations.merge(with: conversations)
            if let exception = validateRatio(
                decodedConversations,
                conversationIDs
            ) {
                return exception
            }

            await commitToMemory(decodedConversations)
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

    // MARK: - Auxiliary

    private func commitToMemory(_ conversations: Set<Conversation>) async {
        @Dependency(\.networking.conversationService.archive) var conversationArchive: ConversationArchiveService

        guard !Task.isCancelled else { return }

        await MainActor.run {
            conversationIDs = conversations.map(\.id)
            self.conversations = Array(conversations).sortedByLatestMessageSentDate
        }

        conversationArchive.addValues(conversations)
    }

    private func validateRatio(
        _ firstComparator: any Collection,
        _ secondComparator: any Collection
    ) -> Exception? {
        guard firstComparator.count == secondComparator.count else {
            return .init(
                "Mismatched ratio returned.",
                metadata: .init(sender: self)
            )
        }

        return nil
    }
}
