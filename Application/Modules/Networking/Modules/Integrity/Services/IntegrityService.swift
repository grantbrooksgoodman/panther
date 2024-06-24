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

    // MARK: - Properties

    private var _session: IntegrityServiceSession?

    // MARK: - Computed Properties

    private var malformedMessageIDs: [String] { getMalformedMessageIDs() }
    private var session: IntegrityServiceSession { getSession() }

    // MARK: - Init

    public init() {}

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
