//
//  DatabaseDelegate+CommonNetworkingExtensions.swift
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

extension DatabaseDelegate {
    func clearTemporaryCaches() {
        CoreDatabaseStore.filter { $0.value.expiryThreshold != .seconds(300) }
    }

    func populateTemporaryCaches() async -> Exception? {
        @Dependency(\.build.milestone) var buildMilestone: Build.Milestone // swiftlint:disable:next identifier_name
        @Dependency(\.networking.database) var _database: DatabaseDelegate

        guard !RuntimeStorage.populatedTemporaryCaches else { return nil }
        let database = LockIsolated<DatabaseDelegate>(_database)

        async let getConversationValues = database.wrappedValue.getValues(
            at: NetworkPath.conversations.rawValue
        )

        async let getMessageValues = database.wrappedValue.getValues(
            at: NetworkPath.messages.rawValue
        )

        async let getUserValues = database.wrappedValue.getValues(
            at: NetworkPath.users.rawValue
        )

        let (conversationResult, messageResult, userResult) = await (
            getConversationValues,
            getMessageValues,
            getUserValues
        )

        let conversationData: [String: Any]
        let messageData: [String: Any]
        let userData: [String: Any]

        switch conversationResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .Networking.typecastFailed(
                    "dictionary",
                    metadata: .init(sender: self)
                )
            }

            conversationData = dictionary

        case let .failure(exception):
            return exception
        }

        switch messageResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .Networking.typecastFailed(
                    "dictionary",
                    metadata: .init(sender: self)
                )
            }

            messageData = dictionary

        case let .failure(exception):
            return exception
        }

        switch userResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .Networking.typecastFailed(
                    "dictionary",
                    metadata: .init(sender: self)
                )
            }

            userData = dictionary

        case let .failure(exception):
            return exception
        }

        let environmentPrefix = Networking.config.environment.shortString
        let conversationKeyPrefix = "\(environmentPrefix)/\(NetworkPath.conversations.rawValue)/"
        let messageKeyPrefix = "\(environmentPrefix)/\(NetworkPath.messages.rawValue)/"
        let userKeyPrefix = "\(environmentPrefix)/\(NetworkPath.users.rawValue)/"

        let expiryThreshold: Duration = .seconds(300)

        for (key, value) in conversationData {
            CoreDatabaseStore.addValue(
                .init(data: value, expiresAfter: expiryThreshold),
                forKey: conversationKeyPrefix + key
            )
        }

        for (key, value) in messageData {
            CoreDatabaseStore.addValue(
                .init(data: value, expiresAfter: expiryThreshold),
                forKey: messageKeyPrefix + key
            )
        }

        for (key, value) in userData {
            CoreDatabaseStore.addValue(
                .init(data: value, expiresAfter: expiryThreshold),
                forKey: userKeyPrefix + key
            )
        }

        if buildMilestone != .generalRelease {
            Task { @MainActor in
                Toast.show(.init(
                    .capsule(style: .info),
                    message: "Established database snapshot.",
                    perpetuation: .ephemeral(.milliseconds(1500))
                ))
            }
        }

        Logger.log(
            "Established database snapshot.",
            domain: .Networking.database,
            sender: self
        )

        RuntimeStorage.store(true, as: .populatedTemporaryCaches)
        return nil
    }
}
