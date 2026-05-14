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

final class IntegrityServiceSession: @unchecked Sendable {
    // MARK: - Types

    struct Indices {
        /* MARK: Properties */

        let conversationsByMessageID: [String: Set<String>]
        let existingConversationIDs: Set<String>
        let existingMessageIDs: Set<String>
        let existingUserIDs: Set<String>
        let usersByConversationIDKey: [String: Set<String>]

        /* MARK: Computed Properties */

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

    static let empty: IntegrityServiceSession = .init(
        conversationData: [:],
        messageData: [:],
        translationData: [:],
        userData: [:]
    )

    let conversationData: [String: Any]
    let indices: Indices
    let messageData: [String: Any]
    let translationData: [String: [String: Any]]
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

    // swiftlint:disable:next function_body_length
    static func resolve(_ failureStrategy: BatchFailureStrategy) async -> Callback<IntegrityServiceSession, Exception> {
        var conversationData: [String: Any]?
        var messageData: [String: Any]?
        var translationData: [String: [String: Any]]?
        var userData: [String: Any]?

        let typecastFailedException = Exception.Networking.typecastFailed(
            "dictionary",
            metadata: .init(sender: self)
        )

        // FIXME: Audit this approach.
        // Fetch all data concurrently
        // Each helper resolves its own @Dependency(\.networking) so no non-Sendable.
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
        ) = await (getConversationValues, getMessageValues, getTranslationValues, getUserValues)

        // Process conversation values

        switch getConversationValuesResult {
        case let .success(values):
            if let dictionary = values as? [String: Any] {
                conversationData = dictionary
            } else {
                guard failureStrategy == .continueOnFailure else {
                    return .failure(typecastFailedException)
                }

                Logger.log(typecastFailedException)
                conversationData = .init()
            }

        case let .failure(exception):
            guard failureStrategy == .continueOnFailure else {
                return .failure(exception)
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
                    return .failure(typecastFailedException)
                }

                Logger.log(typecastFailedException)
                messageData = .init()
            }

        case let .failure(exception):
            guard failureStrategy == .continueOnFailure else {
                return .failure(exception)
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
                    return .failure(typecastFailedException)
                }

                Logger.log(typecastFailedException)
                translationData = .init()
            }

        case let .failure(exception):
            guard failureStrategy == .continueOnFailure else {
                return .failure(exception)
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
                    return .failure(typecastFailedException)
                }

                Logger.log(typecastFailedException)
                userData = .init()
            }

        case let .failure(exception):
            guard failureStrategy == .continueOnFailure else {
                return .failure(exception)
            }

            Logger.log(exception)
            userData = .init()
        }

        guard let conversationData,
              let messageData,
              let translationData,
              let userData else {
            return .failure(.init(metadata: .init(sender: self)))
        }

        return .success(.init(
            conversationData: conversationData,
            messageData: messageData,
            translationData: translationData,
            userData: userData
        ))
    }

    // MARK: - Auxiliary

    private static func fetchDatabaseValues(at path: String) async -> Callback<Any, Exception> {
        await .asCallback {
            @Dependency(\.networking.database) var database: DatabaseDelegate
            return try await database.getValues(at: path)
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
            guard let dictionary = data as? [String: Any],
                  let messageIDs = dictionary[Conversation.SerializableKey.messages.rawValue] as? [String] else { continue }

            for messageID in messageIDs {
                conversationsByMessageID[messageID, default: []].insert(conversationID)
            }
        }

        for (userID, data) in userData {
            guard let dictionary = data as? [String: Any],
                  let conversationIDStrings = dictionary[User.SerializableKey.conversationIDs.rawValue] as? [String] else { continue }

            for idKey in conversationIDStrings.compactMap({
                $0.components(separatedBy: " | ").first
            }) {
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
