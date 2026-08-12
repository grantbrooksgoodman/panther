//
//  IntegrityServiceSession.swift
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

/// A snapshot of the hosted database's conversation, message, translation, and user data, used by
/// the integrity service's repair passes.
struct IntegrityServiceSession: @unchecked Sendable {
    // MARK: - Types

    /// A set of lookup indices derived from a database snapshot.
    struct Indices {
        /* MARK: Properties */

        /// The identifiers of the conversations that reference each message, keyed by message
        /// identifier.
        let conversationsByMessageID: [String: Set<String>]

        /// The identifiers of every conversation in the snapshot.
        let existingConversationIDs: Set<String>

        /// The identifiers of every message in the snapshot.
        let existingMessageIDs: Set<String>

        /// The identifiers of every user in the snapshot.
        let existingUserIDs: Set<String>

        /// The identifiers of the users that reference each conversation, keyed by conversation
        /// identifier key.
        let usersByConversationIDKey: [String: Set<String>]

        /* MARK: Computed Properties */

        /// An empty set of indices.
        static let empty: Indices = .init(
            conversationsByMessageID: [:],
            existingConversationIDs: [],
            existingMessageIDs: [],
            existingUserIDs: [],
            usersByConversationIDKey: [:]
        )

        /* MARK: Init */

        fileprivate init(
            conversationsByMessageID: [String: Set<String>],
            existingConversationIDs: Set<String>,
            existingMessageIDs: Set<String>,
            existingUserIDs: Set<String>,
            usersByConversationIDKey: [String: Set<String>]
        ) {
            self.conversationsByMessageID = conversationsByMessageID
            self.existingConversationIDs = existingConversationIDs
            self.existingMessageIDs = existingMessageIDs
            self.existingUserIDs = existingUserIDs
            self.usersByConversationIDKey = usersByConversationIDKey
        }
    }

    // MARK: - Properties

    /// An empty database snapshot.
    static let empty: IntegrityServiceSession = .init(
        conversationData: [:],
        messageData: [:],
        translationData: [:],
        userData: [:]
    )

    /// The raw conversation data, keyed by conversation identifier key.
    let conversationData: [String: Any]

    /// The lookup indices derived from the snapshot.
    let indices: Indices

    /// The raw message data, keyed by message identifier.
    let messageData: [String: Any]

    /// The raw translation data, keyed by language pair.
    let translationData: [String: [String: Any]]

    /// The raw user data, keyed by user identifier.
    let userData: [String: Any]

    // MARK: - Init

    private init(
        conversationData: [String: Any],
        messageData: [String: Any],
        translationData: [String: [String: Any]],
        userData: [String: Any]
    ) {
        self.conversationData = conversationData
        self.messageData = messageData
        self.translationData = translationData
        self.userData = userData

        indices = Self.resolveIndices(
            conversationData: conversationData,
            messageData: messageData,
            translationData: translationData,
            userData: userData
        )
    }

    // MARK: - Resolve

    // swiftlint:disable function_body_length
    /// Resolves a snapshot of the database into a session.
    ///
    /// This method fetches the conversation, message, translation, and user data concurrently.
    /// Depending on the given failure strategy, a failure to fetch or decode a node either aborts
    /// resolution or substitutes empty data for that node so resolution can continue.
    ///
    /// - Parameter failureStrategy: The strategy that determines whether resolution aborts or
    ///   continues when a node cannot be fetched or decoded.
    ///
    /// - Returns: The resolved database snapshot.
    ///
    /// - Throws: An `Exception` if a node cannot be fetched or decoded and the failure strategy
    ///   does not permit continuing.
    static func resolve(
        _ failureStrategy: BatchFailureStrategy
    ) async throws(Exception) -> IntegrityServiceSession {
        var conversationData: [String: Any]?
        var messageData: [String: Any]?
        var translationData: [String: [String: Any]]?
        var userData: [String: Any]?

        let typecastFailedException = Exception.Networking.typecastFailed(
            "dictionary",
            metadata: .init(sender: self)
        )

        // Fetch all data concurrently.
        // Each helper resolves its own @Dependency(\.networking), so no non-Sendable.
        // NetworkServices value is shared (sent) across concurrent child tasks.

        async let getConversationValues = fetchDatabaseValues(
            at: NetworkPath.conversations.rawValue
        )

        async let getMessageValues = fetchDatabaseValues(
            at: NetworkPath.messages.rawValue
        )

        async let getTranslationValues = fetchDatabaseValues(
            at: NetworkPath.translations.rawValue
        )

        async let getUserValues = fetchDatabaseValues(
            at: NetworkPath.users.rawValue
        )

        let (
            getConversationValuesResult,
            getMessageValuesResult,
            getTranslationValuesResult,
            getUserValuesResult
        ) = await (
            getConversationValues,
            getMessageValues,
            getTranslationValues,
            getUserValues
        )

        // Process conversation values

        switch getConversationValuesResult {
        case let .success(values):
            if let dictionary = values as? [String: Any] {
                conversationData = dictionary
            } else {
                guard failureStrategy == .continueOnFailure else {
                    throw typecastFailedException
                }

                Logger.log(typecastFailedException)
                conversationData = .init()
            }

        case let .failure(exception):
            guard failureStrategy == .continueOnFailure else {
                throw exception
            }

            Logger.log(exception)
            conversationData = .init()
        }

        // Process message values

        switch getMessageValuesResult {
        case let .success(values):
            if let dictionary = values as? [String: Any] {
                messageData = dictionary
            } else {
                guard failureStrategy == .continueOnFailure else {
                    throw typecastFailedException
                }

                Logger.log(typecastFailedException)
                messageData = .init()
            }

        case let .failure(exception):
            guard failureStrategy == .continueOnFailure else {
                throw exception
            }

            Logger.log(exception)
            messageData = .init()
        }

        // Process translation values

        switch getTranslationValuesResult {
        case let .success(values):
            if let dictionary = values as? [String: [String: Any]] {
                translationData = dictionary
            } else {
                guard failureStrategy == .continueOnFailure else {
                    throw typecastFailedException
                }

                Logger.log(typecastFailedException)
                translationData = .init()
            }

        case let .failure(exception):
            guard failureStrategy == .continueOnFailure else {
                throw exception
            }

            Logger.log(exception)
            translationData = .init()
        }

        // Process user values

        switch getUserValuesResult {
        case let .success(values):
            if let dictionary = values as? [String: Any] {
                userData = dictionary
            } else {
                guard failureStrategy == .continueOnFailure else {
                    throw typecastFailedException
                }

                Logger.log(typecastFailedException)
                userData = .init()
            }

        case let .failure(exception):
            guard failureStrategy == .continueOnFailure else {
                throw exception
            }

            Logger.log(exception)
            userData = .init()
        }

        guard let conversationData,
              let messageData,
              let translationData,
              let userData else {
            throw Exception(
                metadata: .init(sender: self)
            )
        }

        return .init(
            conversationData: conversationData,
            messageData: messageData,
            translationData: translationData,
            userData: userData
        )
    } // swiftlint:enable function_body_length

    // MARK: - Auxiliary

    private static func fetchDatabaseValues(
        at path: String
    ) async -> Callback<Any, Exception> {
        await .asCallback {
            @Dependency(\.networking.database) var database: DatabaseDelegate
            return try await database.getValues(
                at: path,
                timeout: .seconds(60)
            )
        }
    }

    private static func resolveIndices(
        conversationData: [String: Any],
        messageData: [String: Any],
        translationData: [String: [String: Any]],
        userData: [String: Any]
    ) -> Indices {
        var conversationsByMessageID = [String: Set<String>]()
        var usersByConversationIDKey = [String: Set<String>]()

        for (conversationID, data) in conversationData {
            guard let dictionary = data as? [String: Any] else { continue }

            guard let map = dictionary[Conversation.SerializableKey.messages.rawValue] as? [String: Any] else { continue }
            let messageIDs = Array(map.keys)

            for messageID in messageIDs {
                conversationsByMessageID[messageID, default: []].insert(conversationID)
            }
        }

        for (userID, data) in userData {
            guard let dictionary = data as? [String: Any] else { continue }

            guard let map = dictionary[User.SerializableKey.conversationIDs.rawValue] as? [String: Any] else { continue }
            let conversationIDKeys = Array(map.keys)

            for idKey in conversationIDKeys {
                usersByConversationIDKey[idKey, default: []].insert(userID)
            }
        }

        return .init(
            conversationsByMessageID: conversationsByMessageID,
            existingConversationIDs: Set(conversationData.keys),
            existingMessageIDs: Set(messageData.keys),
            existingUserIDs: Set(userData.keys),
            usersByConversationIDKey: usersByConversationIDKey
        )
    }
}
