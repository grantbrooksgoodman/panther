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

public final class IntegrityServiceSession {
    // MARK: - Properties

    public static let empty: IntegrityServiceSession = .init(
        conversationData: [:],
        messageData: [:],
        translationData: [:],
        userData: [:]
    )

    public let conversationData: [String: Any]
    public let messageData: [String: Any]
    public let translationData: [String: [String: Any]]
    public let userData: [String: Any]

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
    }

    // MARK: - Resolve

    public static func resolve(_ failureStrategy: BatchFailureStrategy) async -> Callback<IntegrityServiceSession, Exception> {
        @Dependency(\.networking) var networking: NetworkServices

        var conversationData: [String: Any]?
        var messageData: [String: Any]?
        var translationData: [String: [String: Any]]?
        var userData: [String: Any]?

        let typecastFailedException = Exception.Networking.typecastFailed(
            "dictionary",
            metadata: [self, #file, #function, #line]
        )

        // Get Conversation Values

        let getConversationValuesResult = await networking.database.getValues(at: NetworkPath.conversations.rawValue)

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

        // Get Message Values

        let getMessageValuesResult = await networking.database.getValues(at: NetworkPath.messages.rawValue)

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

        // Get Translation Values

        let getTranslationValuesResult = await networking.database.getValues(at: NetworkPath.translations.rawValue)

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

        // Get User Values

        let getUserValuesResult = await networking.database.getValues(at: NetworkPath.users.rawValue)

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
            return .failure(.init(metadata: [self, #file, #function, #line]))
        }

        return .success(.init(
            conversationData: conversationData,
            messageData: messageData,
            translationData: translationData,
            userData: userData
        ))
    }
}
