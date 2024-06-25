//
//  IntegrityServiceSession.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public final class IntegrityServiceSession {
    // MARK: - Properties

    public let conversationData: [String: Any]
    public let messageData: [String: Any]
    public let translationData: [String: Any]
    public let userData: [String: Any]
    public let userNumberHashData: [String: Any]

    // MARK: - Computed Properties

    public static var empty: IntegrityServiceSession {
        .init(
            conversationData: [:],
            messageData: [:],
            translationData: [:],
            userData: [:],
            userNumberHashData: [:]
        )
    }

    // MARK: - Init

    private init(
        conversationData: [String: Any],
        messageData: [String: Any],
        translationData: [String: Any],
        userData: [String: Any],
        userNumberHashData: [String: Any]
    ) {
        self.conversationData = conversationData
        self.messageData = messageData
        self.translationData = translationData
        self.userData = userData
        self.userNumberHashData = userNumberHashData
    }

    // MARK: - Resolve

    public static func resolve() async -> Callback<IntegrityServiceSession, Exception> {
        @Dependency(\.networking) var networking: Networking

        var conversationData: [String: Any]?
        var messageData: [String: Any]?
        var translationData: [String: Any]?
        var userData: [String: Any]?
        var userNumberHashData: [String: Any]?

        // Get Conversation Values

        let getConversationValuesResult = await networking.database.getValues(at: networking.config.paths.conversations)

        switch getConversationValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .failure(.typecastFailed("dictionary", metadata: [self, #file, #function, #line]))
            }

            conversationData = dictionary

        case let .failure(exception):
            return .failure(exception)
        }

        // Get Message Values

        let getMessageValuesResult = await networking.database.getValues(at: networking.config.paths.messages)

        switch getMessageValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .failure(.typecastFailed("dictionary", metadata: [self, #file, #function, #line]))
            }

            messageData = dictionary

        case let .failure(exception):
            return .failure(exception)
        }

        // Get Translation Values

        let getTranslationValuesResult = await networking.database.getValues(at: networking.config.paths.translations)

        switch getTranslationValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .failure(.typecastFailed("dictionary", metadata: [self, #file, #function, #line]))
            }

            translationData = dictionary

        case let .failure(exception):
            return .failure(exception)
        }

        // Get User Values

        let getUserValuesResult = await networking.database.getValues(at: networking.config.paths.users)

        switch getUserValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .failure(.typecastFailed("dictionary", metadata: [self, #file, #function, #line]))
            }

            userData = dictionary

        case let .failure(exception):
            return .failure(exception)
        }

        // Get User Number Hashes

        let getUserNumberHashValuesResult = await networking.database.getValues(at: networking.config.paths.userNumberHashes)

        switch getUserNumberHashValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .failure(.typecastFailed("dictionary", metadata: [self, #file, #function, #line]))
            }

            userNumberHashData = dictionary

        case let .failure(exception):
            return .failure(exception)
        }

        guard let conversationData,
              let messageData,
              let translationData,
              let userData,
              let userNumberHashData else {
            return .failure(.init(metadata: [self, #file, #function, #line]))
        }

        return .success(.init(
            conversationData: conversationData,
            messageData: messageData,
            translationData: translationData,
            userData: userData,
            userNumberHashData: userNumberHashData
        ))
    }
}
