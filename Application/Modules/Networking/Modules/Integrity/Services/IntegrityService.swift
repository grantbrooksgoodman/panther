//
//  IntegrityService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public final class IntegrityService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.commonServices.remoteCache) private var remoteCacheService: RemoteCacheService

    // MARK: - Properties

    private var _session: IntegrityServiceSession?

    // MARK: - Computed Properties

    private var malformedConversationIDKeys: [String] { getMalformedConversationIDKeys() }
    private var malformedMessageIDs: [String] { getMalformedMessageIDs() }
    private var malformedUserIDs: [String] { getMalformedUserIDs() }
    private var session: IntegrityServiceSession { getSession() }

    // MARK: - Init

    public init() {}

    // MARK: - Repair

    public func repairMalformedConversations(_ idKeys: [String]? = nil) async -> Exception? {
        var exceptions = [Exception]()

        for conversationIDKey in idKeys ?? malformedConversationIDKeys {
            for userID in usersReferencing(conversationIDKey: conversationIDKey) {
                guard let dictionary = session.userData[userID] as? [String: Any],
                      var conversationIDStrings = dictionary[User.SerializationKeys.conversationIDs.rawValue] as? [String] else { continue }

                conversationIDStrings = conversationIDStrings.filter { !$0.hasPrefix(conversationIDKey) }

                let keyPath = "\(networking.config.paths.users)/\(userID)/\(User.SerializationKeys.conversationIDs.rawValue)"
                if let exception = await networking.database.setValue(
                    conversationIDStrings,
                    forKey: keyPath
                ) {
                    exceptions.append(exception)
                }

                if let exception = await remoteCacheService.setCacheStatus(.invalid, userID: userID) {
                    exceptions.append(exception)
                }
            }

            if let exception = await networking.database.setValue(
                NSNull(),
                forKey: "\(networking.config.paths.conversations)/\(conversationIDKey)"
            ) {
                exceptions.append(exception)
            }

            guard let data = session.conversationData[conversationIDKey] as? [String: Any],
                  let messageIDs = data[Conversation.SerializationKeys.messages.rawValue] as? [String] else { continue }

            for messageID in messageIDs {
                if let exception = await networking.database.setValue(
                    NSNull(),
                    forKey: "\(networking.config.paths.messages)/\(messageID)"
                ) {
                    exceptions.append(exception)
                }
            }
        }

        return exceptions.compiledException
    }

    public func repairMalformedMessages() async -> Exception? {
        var exceptions = [Exception]()

        for messageID in malformedMessageIDs {
            for conversationIDKey in conversationsReferencing(messageID: messageID) {
                for userID in usersReferencing(conversationIDKey: conversationIDKey) {
                    guard let dictionary = session.userData[userID] as? [String: Any],
                          var conversationIDStrings = dictionary[User.SerializationKeys.conversationIDs.rawValue] as? [String] else { continue }

                    conversationIDStrings = conversationIDStrings.filter { !$0.hasPrefix(conversationIDKey) }
                    conversationIDStrings.append("\(conversationIDKey) | \(String.bangQualifiedEmpty)")

                    let keyPath = "\(networking.config.paths.users)/\(userID)/\(User.SerializationKeys.conversationIDs.rawValue)"
                    if let exception = await networking.database.setValue(
                        conversationIDStrings,
                        forKey: keyPath
                    ) {
                        exceptions.append(exception)
                    }

                    if let exception = await remoteCacheService.setCacheStatus(.invalid, userID: userID) {
                        exceptions.append(exception)
                    }
                }

                guard let data = session.conversationData[conversationIDKey] as? [String: Any],
                      var messageIDs = data[Conversation.SerializationKeys.messages.rawValue] as? [String] else { continue }

                messageIDs = messageIDs.filter { $0 != messageID }

                let pathPrefix = "\(networking.config.paths.conversations)/\(conversationIDKey)"
                if let exception = await networking.database.setValue(
                    messageIDs,
                    forKey: "\(pathPrefix)/\(Conversation.SerializationKeys.messages.rawValue)"
                ) {
                    exceptions.append(exception)
                }

                if let exception = await networking.database.setValue(
                    String.bangQualifiedEmpty,
                    forKey: "\(pathPrefix)/\(Conversation.SerializationKeys.encodedHash.rawValue)"
                ) {
                    exceptions.append(exception)
                }
            }

            let keyPath = "\(networking.config.paths.messages)/\(messageID)"
            if let exception = await networking.database.setValue(
                NSNull(),
                forKey: keyPath
            ) {
                exceptions.append(exception)
            }
        }

        return exceptions.compiledException
    }

    public func repairMalformedUsers() async -> Exception? {
        var exceptions = [Exception]()

        for userID in malformedUserIDs {
            guard await networking.services.user.legacy.convertUser(id: userID) != nil,
                  let dictionary = session.userData[userID] as? [String: Any] else { continue }

            if let encodedPhoneNumber = dictionary[User.SerializationKeys.phoneNumber.rawValue] as? [String: Any] {
                let decodeResult = await PhoneNumber.decode(from: encodedPhoneNumber)

                switch decodeResult {
                case let .success(phoneNumber):
                    let userNumberHashesPath = "\(networking.config.paths.userNumberHashes)/\(phoneNumber.nationalNumberString.digits.encodedHash)"
                    let getValuesResult = await networking.database.getValues(at: userNumberHashesPath)

                    switch getValuesResult {
                    case let .success(values):
                        guard var array = values as? [String] else {
                            exceptions.append(.typecastFailed("array", metadata: [self, #file, #function, #line]))
                            continue
                        }

                        array = array.filter { $0 != userID }

                        if array.isEmpty,
                           let exception = await networking.database.setValue(NSNull(), forKey: userNumberHashesPath) {
                            exceptions.append(exception)
                        } else if let exception = await networking.database.setValue(array, forKey: userNumberHashesPath) {
                            exceptions.append(exception)
                        }

                    case let .failure(exception):
                        exceptions.append(exception)
                    }

                case let .failure(exception):
                    exceptions.append(exception)
                }
            }

            if let exception = await networking.database.setValue(
                NSNull(),
                forKey: "\(networking.config.paths.users)/\(userID)"
            ) {
                exceptions.append(exception)
            }

            guard let conversationIDStrings = dictionary[User.SerializationKeys.conversationIDs.rawValue] as? [String] else { continue }

            if let exception = await repairMalformedConversations(conversationIDStrings) {
                exceptions.append(exception)
            }
        }

        return exceptions.compiledException
    }

    // MARK: - Resolve Session

    public func resolveSession() async -> Exception? {
        let resolveResult = await IntegrityServiceSession.resolve()

        switch resolveResult {
        case let .success(session):
            Logger.log(
                "Resolved integrity service session.",
                domain: .dataIntegrity,
                metadata: [self, #file, #function, #line]
            )
            _session = session

        case let .failure(exception):
            return exception
        }

        return nil
    }

    // MARK: - Computed Property Getters

    private func getMalformedConversationIDKeys() -> [String] {
        var conversationIDKeys = [String]()

        for (key, value) in session.conversationData {
            guard var dictionary = value as? [String: Any] else {
                conversationIDKeys.append(key)
                continue
            }

            dictionary[Conversation.SerializationKeys.id.rawValue] = key
            guard !Conversation.canDecode(from: dictionary) else { continue }

            conversationIDKeys.append(key)
        }

        return conversationIDKeys
    }

    private func getMalformedMessageIDs() -> [String] {
        var messageIDs = [String]()

        for (key, value) in session.messageData {
            guard var dictionary = value as? [String: Any] else {
                messageIDs.append(key)
                continue
            }

            dictionary[Message.SerializationKeys.id.rawValue] = key
            guard !Message.canDecode(from: dictionary) else { continue }

            messageIDs.append(key)
        }

        return messageIDs
    }

    private func getMalformedUserIDs() -> [String] {
        var userIDs = [String]()

        for (key, value) in session.userData {
            guard var dictionary = value as? [String: Any] else {
                userIDs.append(key)
                continue
            }

            dictionary[User.SerializationKeys.id.rawValue] = key
            guard !User.canDecode(from: dictionary) else { continue }

            userIDs.append(key)
        }

        return userIDs
    }

    private func getSession() -> IntegrityServiceSession {
        // swiftlint:disable:next identifier_name
        guard let _session else {
            Logger.log(.init(
                "Referencing unresolved IntegrityServiceSession.",
                metadata: [self, #file, #function, #line]
            ))

            return .empty
        }

        return _session
    }

    // MARK: - Auxiliary

    /// In practice, only one conversation should ever reference a given message.
    private func conversationsReferencing(messageID: String) -> [String] {
        var referencing = [String]()

        for (key, value) in session.conversationData {
            guard let dictionary = value as? [String: Any],
                  let messageIDs = dictionary[Conversation.SerializationKeys.messages.rawValue] as? [String],
                  messageIDs.contains(messageID) else { continue }

            referencing.append(key)
        }

        return referencing
    }

    private func usersReferencing(conversationIDKey: String) -> [String] {
        var referencing = [String]()

        for (key, value) in session.userData {
            guard let dictionary = value as? [String: Any],
                  let conversationIDStrings = dictionary[User.SerializationKeys.conversationIDs.rawValue] as? [String],
                  conversationIDStrings.contains(where: { $0.hasPrefix(conversationIDKey) }) else { continue }

            referencing.append(key)
        }

        return referencing
    }
}
