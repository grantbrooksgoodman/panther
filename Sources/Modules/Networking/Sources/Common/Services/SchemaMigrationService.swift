//
//  SchemaMigrationService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import CryptoKit
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

/// Performs a one-time, total conversion of the database
/// from the legacy array-based schema to the current
/// keyed-map schema.
///
/// All data is preserved – only the structure changes.
/// Backwards compatibility is not a consideration; after
/// this migration completes, the database contains only
/// new-format nodes.
///
/// The migration reads every user, conversation, and
/// message node, detects legacy-format fields, and builds
/// a single atomic ``DatabaseDelegate/commit(_:)`` payload
/// that rewrites all affected paths in one operation.
///
/// User nodes are also brought fully up to the current
/// schema – required fields introduced by later versions
/// (e.g. `deviceID`) are backfilled with their creation
/// defaults, and retired fields are removed.
///
/// Message nodes have their legacy two-component media
/// `contentType` values (`"<mime> – <id>"`) rewritten to
/// the current explicit-extension format
/// (`"<mime> – <id> – <extension>"`).
struct SchemaMigrationService {
    // MARK: - Types

    private struct MigrationResult {
        let conversationsMigrated: Int
        let messagesMigrated: Int
        let updates: [String: Any]
        let usersMigrated: Int
    }

    // MARK: - Dependencies

    @Dependency(\.networking.database) private var database: DatabaseDelegate
    @Dependency(\.jsonEncoder) private var jsonEncoder: JSONEncoder
    @Dependency(\.timestampDateFormatter) private var timestampDateFormatter: DateFormatter

    // MARK: - Properties

    /// The shared schema migration service.
    static let shared = SchemaMigrationService()

    /// Maps a legacy two-component media content type's MIME to
    /// its canonical file extension, for rewriting legacy values
    /// to the explicit-extension wire format.
    private static let legacyMediaExtensions: [String: String] = [
        "application/pdf": "pdf",
        "image/jpeg": "jpeg",
        "video/mp4": "mp4",
    ]

    // MARK: - Init

    private init() {}

    // MARK: - Migrate Database

    /// Reads every user, conversation, and message node,
    /// converts legacy array-format fields to keyed maps,
    /// backfills required user fields introduced by later
    /// schema versions, recomputes version tokens, persists
    /// `imageHash` where absent, and rewrites legacy media
    /// `contentType` values to the explicit-extension
    /// format. All changes are committed atomically.
    func migrateDatabase() async throws(Exception) {
        Logger.log(
            "Starting full database schema migration.",
            domain: .schemaMigration,
            sender: self
        )

        let userData: [String: Any]
        let conversationData: [String: Any]
        let messageData: [String: Any]

        do {
            userData = try await database.getValues(
                at: NetworkPath.users.rawValue,
                cacheStrategy: .disregardCache
            )

            conversationData = try await database.getValues(
                at: NetworkPath.conversations.rawValue,
                cacheStrategy: .disregardCache
            )

            messageData = try await database.getValues(
                at: NetworkPath.messages.rawValue,
                cacheStrategy: .disregardCache
            )
        } catch {
            throw error
        }

        var updates = [String: Any]()

        let userResult = migrateUsers(userData)
        updates.merge(
            userResult.updates,
            uniquingKeysWith: { _, new in new }
        )

        let conversationResult = migrateConversations(conversationData)
        updates.merge(
            conversationResult.updates,
            uniquingKeysWith: { _, new in new }
        )

        let messageResult = migrateMessageContentTypes(messageData)
        updates.merge(
            messageResult.updates,
            uniquingKeysWith: { _, new in new }
        )

        guard !updates.isEmpty else {
            Logger.log(
                "No legacy-format nodes found. Database is already migrated.",
                domain: .schemaMigration,
                sender: self
            )

            return
        }

        Logger.log(
            "Committing migration: \(userResult.usersMigrated) user(s), "
                + "\(conversationResult.conversationsMigrated) conversation(s), "
                + "\(messageResult.messagesMigrated) message(s), "
                + "\(updates.count) path(s).",
            domain: .schemaMigration,
            sender: self
        )

        let reconciledUpdates = reconcileOverlappingPaths(updates)
        try await database.commit(reconciledUpdates)

        Logger.log(
            "Database schema migration completed successfully.",
            domain: .schemaMigration,
            sender: self
        )
    }

    // MARK: - User Migration

    private func migrateUsers(
        _ userData: [String: Any]
    ) -> MigrationResult {
        var updates = [String: Any]()
        var usersMigrated = 0

        for (userID, rawUser) in userData {
            guard let userDictionary = rawUser as? [String: Any] else { continue }

            var didMigrateUser = false
            let userPath = "\(NetworkPath.users.rawValue)/\(userID)"

            // blockedUserIDs: ["userID", ...] → { "userID": true, ... }
            if let blockedUserIDUpdates = migrateBlockedUserIDs(
                userDictionary,
                userPath: userPath
            ) {
                updates.merge(
                    blockedUserIDUpdates,
                    uniquingKeysWith: { _, new in new }
                )

                didMigrateUser = true
            }

            // openConversations: ["key | hash", ...] → { "key": "hash", ... }
            if let conversationIDUpdates = migrateConversationIDs(
                userDictionary,
                userPath: userPath
            ) {
                updates.merge(
                    conversationIDUpdates,
                    uniquingKeysWith: { _, new in new }
                )

                didMigrateUser = true
            }

            // pushTokens: ["token", ...] → { "token": true, ... }
            if let pushTokenUpdates = migratePushTokens(
                userDictionary,
                userPath: userPath
            ) {
                updates.merge(
                    pushTokenUpdates,
                    uniquingKeysWith: { _, new in new }
                )

                didMigrateUser = true
            }

            // Required fields absent from nodes written by
            // earlier schema versions.
            if let requiredFieldUpdates = backfillRequiredUserFields(
                userDictionary,
                userPath: userPath
            ) {
                updates.merge(
                    requiredFieldUpdates,
                    uniquingKeysWith: { _, new in new }
                )

                didMigrateUser = true
            }

            if didMigrateUser {
                usersMigrated += 1
            }
        }

        return .init(
            conversationsMigrated: 0,
            messagesMigrated: 0,
            updates: updates,
            usersMigrated: usersMigrated
        )
    }

    // MARK: - Conversation Migration

    private func migrateConversations(
        _ conversationData: [String: Any]
    ) -> MigrationResult {
        var updates = [String: Any]()
        var conversationsMigrated = 0

        for (conversationIDKey, rawConversation) in conversationData {
            guard let conversationDictionary = rawConversation as? [String: Any] else { continue }

            var didMigrateConversation = false
            let conversationPath = "\(NetworkPath.conversations.rawValue)/\(conversationIDKey)"

            // messages: ["msgID", ...] → { "msgID": true, ... }
            if let messageUpdates = migrateMessages(
                conversationDictionary,
                conversationPath: conversationPath
            ) {
                updates.merge(
                    messageUpdates,
                    uniquingKeysWith: { _, new in new }
                )

                didMigrateConversation = true
            }

            // participants: ["uid | bool | bool", ...] →
            // { "userID": { "hasDeletedConversation": bool, "isTyping": bool }, ... }
            if let participantUpdates = migrateParticipants(
                conversationDictionary,
                conversationPath: conversationPath
            ) {
                updates.merge(
                    participantUpdates,
                    uniquingKeysWith: { _, new in new }
                )

                didMigrateConversation = true
            }

            // metadata/imageHash: compute and persist if
            // imageData exists but imageHash doesn't.
            if let imageHashUpdates = migrateImageHash(
                conversationDictionary,
                conversationPath: conversationPath
            ) {
                updates.merge(
                    imageHashUpdates,
                    uniquingKeysWith: { _, new in new }
                )

                didMigrateConversation = true
            }

            // Recompute hash after structural changes.
            if didMigrateConversation {
                if let hashUpdate = recomputeHash(
                    conversationDictionary,
                    conversationIDKey: conversationIDKey,
                    conversationPath: conversationPath,
                    pendingUpdates: updates
                ) {
                    updates.merge(
                        hashUpdate,
                        uniquingKeysWith: { _, new in new }
                    )
                }

                conversationsMigrated += 1
            }
        }

        return .init(
            conversationsMigrated: conversationsMigrated,
            messagesMigrated: 0,
            updates: updates,
            usersMigrated: 0
        )
    }

    // MARK: - Message Migration

    private func migrateMessageContentTypes(
        _ messageData: [String: Any]
    ) -> MigrationResult {
        // Message contentType is not a conversation hash factor
        // (only message IDs are), and message nodes carry no
        // persisted hash, so no hash recomputation or fan-out
        // is required here.
        var updates = [String: Any]()
        var messagesMigrated = 0

        for (messageID, rawMessage) in messageData {
            guard let messageDictionary = rawMessage as? [String: Any],
                  let contentType = messageDictionary[
                      Message.SerializableKey.contentType.rawValue
                  ] as? String else { continue }

            let components = contentType.components(separatedBy: " – ")
            guard components.count == 2,
                  let fileExtension = Self.legacyMediaExtensions[components[0]] else { continue }

            let path = [
                NetworkPath.messages.rawValue,
                messageID,
                Message.SerializableKey.contentType.rawValue,
            ].joined(separator: "/")

            updates[path] = "\(contentType) – \(fileExtension)"
            messagesMigrated += 1
        }

        return .init(
            conversationsMigrated: 0,
            messagesMigrated: messagesMigrated,
            updates: updates,
            usersMigrated: 0
        )
    }

    // MARK: - User Field Migration

    /// Supplies creation defaults for required fields the
    /// current `User` decoder demands but which nodes
    /// written by earlier schema versions may lack, and
    /// removes the retired `lastSignedIn` field.
    private func backfillRequiredUserFields(
        _ userDictionary: [String: Any],
        userPath: String
    ) -> [String: Any]? {
        var updates = [String: Any]()

        if !(userDictionary[User.SerializableKey.aiEnhancedTranslationsEnabled.rawValue] is Bool) {
            updates["\(userPath)/\(User.SerializableKey.aiEnhancedTranslationsEnabled.rawValue)"] = false
        }

        if !(userDictionary[User.SerializableKey.deviceID.rawValue] is String) {
            updates["\(userPath)/\(User.SerializableKey.deviceID.rawValue)"] = String.bangQualifiedEmpty
        }

        if !(userDictionary[User.SerializableKey.isPenPalsParticipant.rawValue] is Bool) {
            updates["\(userPath)/\(User.SerializableKey.isPenPalsParticipant.rawValue)"] = false
        }

        if !(userDictionary[User.SerializableKey.messageRecipientConsentRequired.rawValue] is Bool) {
            updates["\(userPath)/\(User.SerializableKey.messageRecipientConsentRequired.rawValue)"] = false
        }

        if !(userDictionary[User.SerializableKey.previousLanguageCodes.rawValue] is [String]) {
            updates["\(userPath)/\(User.SerializableKey.previousLanguageCodes.rawValue)"] = [String].bangQualifiedEmpty
        }

        let lastSignedInKey = "lastSignedIn"
        if userDictionary[lastSignedInKey] != nil {
            updates["\(userPath)/\(lastSignedInKey)"] = NSNull()
        }

        return updates.isEmpty ? nil : updates
    }

    private func migrateBlockedUserIDs(
        _ userDictionary: [String: Any],
        userPath: String
    ) -> [String: Any]? {
        guard let array = userDictionary[
            User.SerializableKey.blockedUserIDs.rawValue
        ] as? [String] else { return nil }

        let path = "\(userPath)/\(User.SerializableKey.blockedUserIDs.rawValue)"

        // Empty or bang-qualified arrays become empty maps.
        guard !array.isEmpty,
              !array.isBangQualifiedEmpty else {
            return [path: [String: Bool]()]
        }

        var map = [String: Bool]()
        for userID in array {
            map[userID] = true
        }

        return [path: map]
    }

    private func migrateConversationIDs(
        _ userDictionary: [String: Any],
        userPath: String
    ) -> [String: Any]? {
        guard let array = userDictionary[
            User.SerializableKey.conversationIDs.rawValue
        ] as? [String] else { return nil }

        let path = "\(userPath)/\(User.SerializableKey.conversationIDs.rawValue)"

        guard !array.isEmpty,
              !array.isBangQualifiedEmpty else {
            return [path: [String: String]()]
        }

        var map = [String: String]()
        for entry in array {
            let components = entry.components(separatedBy: " | ")
            guard components.count == 2 else { continue }
            map[components[0]] = components[1]
        }

        return [path: map]
    }

    private func migratePushTokens(
        _ userDictionary: [String: Any],
        userPath: String
    ) -> [String: Any]? {
        guard let array = userDictionary[
            User.SerializableKey.pushTokens.rawValue
        ] as? [String] else { return nil }

        let path = "\(userPath)/\(User.SerializableKey.pushTokens.rawValue)"

        guard !array.isEmpty,
              !array.isBangQualifiedEmpty else {
            return [path: [String: Bool]()]
        }

        var map = [String: Bool]()
        for token in array {
            map[token] = true
        }

        return [path: map]
    }

    // MARK: - Conversation Field Migration

    private func migrateImageHash(
        _ conversationDictionary: [String: Any],
        conversationPath: String
    ) -> [String: Any]? {
        guard let metadata = conversationDictionary[
            Conversation.SerializableKey.metadata.rawValue
        ] as? [String: Any] else { return nil }

        // Already has imageHash – nothing to do.
        guard metadata[
            ConversationMetadata.SerializableKey.imageHash.rawValue
        ] == nil else { return nil }

        // No imageData to hash.
        guard let imageDataString = metadata[
            ConversationMetadata.SerializableKey.imageData.rawValue
        ] as? String,
            !imageDataString.isBangQualifiedEmpty,
            let imageData = Data(base64Encoded: imageDataString) else { return nil }

        let imageHash = ConversationMetadata.computeImageHash(imageData)
        let path = [
            conversationPath,
            Conversation.SerializableKey.metadata.rawValue,
            ConversationMetadata.SerializableKey.imageHash.rawValue,
        ].joined(separator: "/")

        return [path: imageHash]
    }

    private func migrateMessages(
        _ conversationDictionary: [String: Any],
        conversationPath: String
    ) -> [String: Any]? {
        guard let array = conversationDictionary[
            Conversation.SerializableKey.messages.rawValue
        ] as? [String] else { return nil }

        let path = "\(conversationPath)/\(Conversation.SerializableKey.messages.rawValue)"
        let messageIDs = array.filter { $0.hasPrefix("-") }

        guard !messageIDs.isEmpty else {
            return [path: [String: Bool]()]
        }

        var map = [String: Bool]()
        for messageID in messageIDs {
            map[messageID] = true
        }

        return [path: map]
    }

    private func migrateParticipants(
        _ conversationDictionary: [String: Any],
        conversationPath: String
    ) -> [String: Any]? {
        guard let array = conversationDictionary[
            Conversation.SerializableKey.participants.rawValue
        ] as? [String] else { return nil }

        let path = "\(conversationPath)/\(Conversation.SerializableKey.participants.rawValue)"

        var map = [String: [String: Any]]()
        for entry in array {
            let components = entry.components(separatedBy: " | ")
            guard components.count == 3 else { continue }

            map[components[0]] = [
                Participant.SerializableKey.hasDeletedConversation.rawValue: components[1] == "true",
                Participant.SerializableKey.isTyping.rawValue: components[2] == "true",
            ]
        }

        return [path: map]
    }

    // MARK: - Hash Recomputation

    /// Recomputes the conversation's `encodedHash` using
    /// the current hash-factor formula and writes it to
    /// the conversation node. Also fans out the new token
    /// to each participant's `openConversations` entry.
    private func recomputeHash(
        _ conversationDictionary: [String: Any],
        conversationIDKey: String,
        conversationPath: String,
        pendingUpdates: [String: Any]
    ) -> [String: Any]? {
        var factors = [conversationIDKey]

        factors.append(contentsOf: activityHashFactors(conversationDictionary))

        factors.append(contentsOf: messageIDHashFactors(
            conversationDictionary,
            conversationPath: conversationPath,
            pendingUpdates: pendingUpdates
        ))

        factors.append(contentsOf: metadataHashFactors(
            conversationDictionary,
            conversationPath: conversationPath,
            pendingUpdates: pendingUpdates
        ))

        factors.append(contentsOf: participantHashFactors(
            conversationDictionary,
            conversationPath: conversationPath,
            pendingUpdates: pendingUpdates
        ))

        factors.append(contentsOf: reactionMetadataHashFactors(conversationDictionary))

        let sortedFactors = factors.sorted()
        guard let encodedData = try? jsonEncoder.encode(sortedFactors) else { return nil }

        let newHash = SHA256.hash(data: encodedData)
            .compactMap { String(format: "%02x", $0) }
            .joined()

        var result: [String: Any] = [
            "\(conversationPath)/\(Conversation.SerializableKey.encodedHash.rawValue)": newHash,
        ]

        let participantUserIDs = resolveParticipantUserIDs(
            conversationDictionary,
            conversationPath: conversationPath,
            pendingUpdates: pendingUpdates
        )

        for userID in participantUserIDs {
            let tokenPath = [
                NetworkPath.users.rawValue,
                userID,
                User.SerializableKey.conversationIDs.rawValue,
                conversationIDKey,
            ].joined(separator: "/")

            result[tokenPath] = newHash
        }

        return result
    }

    // MARK: - Auxiliary

    private func activityHashFactors(
        _ conversationDictionary: [String: Any]
    ) -> [String] {
        guard let encodedActivities = conversationDictionary[
            Conversation.SerializableKey.activities.rawValue
        ] as? [[String: Any]] else { return [] }

        return encodedActivities.compactMap {
            computeActivityHash(
                $0,
                dateFormatter: timestampDateFormatter,
                jsonEncoder: jsonEncoder
            )
        }
    }

    private func computeActivityHash(
        _ activity: [String: Any],
        dateFormatter: DateFormatter,
        jsonEncoder: JSONEncoder
    ) -> String? {
        guard let action = activity["action"] as? String,
              let dateString = activity["date"] as? String,
              let date = timestampDateFormatter.date(from: dateString),
              let userID = activity["userID"] as? String else { return nil }

        let factors = [
            action,
            dateFormatter.string(from: date),
            userID,
        ].sorted()

        guard let data = try? jsonEncoder.encode(factors) else { return nil }
        return SHA256.hash(data: data)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    private func computeReactionMetadataHash(
        _ reactionMetadata: [String: Any],
        jsonEncoder: JSONEncoder
    ) -> String? {
        guard let messageID = reactionMetadata["messageID"] as? String,
              let reactions = reactionMetadata["reactions"] as? [[String: Any]] else { return nil }

        var factors = [messageID]
        for reaction in reactions {
            if let userID = reaction["userID"] as? String {
                factors.append(userID)
            }

            if let style = reaction["style"] as? String {
                factors.append(style)
            }
        }

        let sortedFactors = factors.sorted()
        guard let data = try? jsonEncoder.encode(sortedFactors) else { return nil }
        return SHA256.hash(data: data)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    private func messageIDHashFactors(
        _ conversationDictionary: [String: Any],
        conversationPath: String,
        pendingUpdates: [String: Any]
    ) -> [String] {
        let messagesPath = "\(conversationPath)/\(Conversation.SerializableKey.messages.rawValue)"

        let messageIDs: [String] = if let migratedMap = pendingUpdates[
            messagesPath
        ] as? [String: Bool] {
            migratedMap.keys.sorted()
        } else if let existingMap = conversationDictionary[
            Conversation.SerializableKey.messages.rawValue
        ] as? [String: Any] {
            existingMap.keys.sorted()
        } else if let existingArray = conversationDictionary[
            Conversation.SerializableKey.messages.rawValue
        ] as? [String] {
            existingArray.filter { $0.hasPrefix("-") }
        } else {
            []
        }

        return messageIDs.filter { $0.hasPrefix("-") }
    }

    private func metadataHashFactors(
        _ conversationDictionary: [String: Any],
        conversationPath: String,
        pendingUpdates: [String: Any]
    ) -> [String] {
        guard let metadata = conversationDictionary[
            Conversation.SerializableKey.metadata.rawValue
        ] as? [String: Any] else { return [] }

        var factors = [String]()

        let name = metadata[
            ConversationMetadata.SerializableKey.name.rawValue
        ] as? String ?? .bangQualifiedEmpty

        factors.append(name)

        let imageHashPath = [
            conversationPath,
            Conversation.SerializableKey.metadata.rawValue,
            ConversationMetadata.SerializableKey.imageHash.rawValue,
        ].joined(separator: "/")

        if let pendingImageHash = pendingUpdates[imageHashPath] as? String {
            factors.append(pendingImageHash)
        } else if let existingImageHash = metadata[
            ConversationMetadata.SerializableKey.imageHash.rawValue
        ] as? String {
            factors.append(existingImageHash)
        } else if let imageDataString = metadata[
            ConversationMetadata.SerializableKey.imageData.rawValue
        ] as? String,
            !imageDataString.isBangQualifiedEmpty,
            let imageData = Data(base64Encoded: imageDataString) {
            factors.append(ConversationMetadata.computeImageHash(imageData))
        } else {
            factors.append(.bangQualifiedEmpty)
        }

        let isPenPals = metadata[
            ConversationMetadata.SerializableKey.isPenPalsConversation.rawValue
        ] as? Bool ?? false

        factors.append(isPenPals.description)

        if let lastModifiedString = metadata[
            ConversationMetadata.SerializableKey.lastModifiedDate.rawValue
        ] as? String,
            let lastModifiedDate = timestampDateFormatter.date(from: lastModifiedString) {
            factors.append(timestampDateFormatter.string(from: lastModifiedDate))
        }

        if let mrcAcknowledgementDataArray = metadata[
            ConversationMetadata.SerializableKey.messageRecipientConsentAcknowledgementData.rawValue
        ] as? [String] {
            factors.append(contentsOf: mrcAcknowledgementDataArray)
        }

        if let penPalsSharingDataArray = metadata[
            ConversationMetadata.SerializableKey.penPalsSharingData.rawValue
        ] as? [String] {
            factors.append(contentsOf: penPalsSharingDataArray)
        }

        let requiresConsent = metadata[
            ConversationMetadata.SerializableKey.requiresConsentFromInitiator.rawValue
        ] as? String

        factors.append(
            requiresConsent == nil || (requiresConsent?.isBangQualifiedEmpty ?? true)
                ? .bangQualifiedEmpty
                : requiresConsent!.description
        )

        return factors
    }

    private func participantHashFactors(
        _ conversationDictionary: [String: Any],
        conversationPath: String,
        pendingUpdates: [String: Any]
    ) -> [String] {
        let participantsPath = "\(conversationPath)/\(Conversation.SerializableKey.participants.rawValue)"

        if let migratedMap = pendingUpdates[participantsPath] as? [String: [String: Any]] {
            return migratedMap.map {
                "\($0.key) | \($0.value[Participant.SerializableKey.hasDeletedConversation.rawValue] as? Bool ?? false)"
            }
        } else if let existingMap = conversationDictionary[
            Conversation.SerializableKey.participants.rawValue
        ] as? [String: [String: Any]] {
            return existingMap.map {
                "\($0.key) | \($0.value[Participant.SerializableKey.hasDeletedConversation.rawValue] as? Bool ?? false)"
            }
        } else if let existingArray = conversationDictionary[
            Conversation.SerializableKey.participants.rawValue
        ] as? [String] {
            return existingArray.compactMap {
                let components = $0.components(separatedBy: " | ")
                guard components.count == 3 else { return nil }
                return "\(components[0]) | \(components[1])"
            }
        }

        return []
    }

    private func reactionMetadataHashFactors(
        _ conversationDictionary: [String: Any]
    ) -> [String] {
        guard let encodedReactionMetadata = conversationDictionary[
            Conversation.SerializableKey.reactionMetadata.rawValue
        ] as? [[String: Any]] else { return [] }

        return encodedReactionMetadata.compactMap {
            computeReactionMetadataHash(
                $0,
                jsonEncoder: jsonEncoder
            )
        }
    }

    private func reconcileOverlappingPaths(
        _ updates: [String: Any]
    ) -> [String: Any] {
        var result = updates
        let allPaths = Array(updates.keys)
        var pathsToRemove = Set<String>()

        for childPath in allPaths {
            guard let childValue = result[childPath] as? String else { continue }

            for parentPath in allPaths where parentPath != childPath {
                guard childPath.hasPrefix("\(parentPath)/") else { continue }

                let childKey = String(childPath.dropFirst(parentPath.count + 1))
                guard !childKey.contains("/") else { continue }

                if var parentMap = result[parentPath] as? [String: String] {
                    parentMap[childKey] = childValue
                    result[parentPath] = parentMap
                    pathsToRemove.insert(childPath)
                    break
                }
            }
        }

        for path in pathsToRemove {
            result.removeValue(forKey: path)
        }

        return result
    }

    private func resolveParticipantUserIDs(
        _ conversationDictionary: [String: Any],
        conversationPath: String,
        pendingUpdates: [String: Any]
    ) -> [String] {
        let participantsPath = "\(conversationPath)/\(Conversation.SerializableKey.participants.rawValue)"

        if let migratedMap = pendingUpdates[participantsPath] as? [String: [String: Any]] {
            return Array(migratedMap.keys)
        } else if let existingMap = conversationDictionary[
            Conversation.SerializableKey.participants.rawValue
        ] as? [String: [String: Any]] {
            return Array(existingMap.keys)
        } else if let existingArray = conversationDictionary[
            Conversation.SerializableKey.participants.rawValue
        ] as? [String] {
            return existingArray.compactMap {
                $0.components(separatedBy: " | ").first
            }
        }

        return []
    }
}

// swiftlint:enable file_length type_body_length
