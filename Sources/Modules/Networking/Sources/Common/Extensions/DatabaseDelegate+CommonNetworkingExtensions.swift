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

    func populateTemporaryCaches() async throws(Exception) {
        @Dependency(\.build.milestone) var buildMilestone: Build.Milestone

        guard !RuntimeStorage.populatedTemporaryCaches else { return }
        let database = LockIsolated(
            Dependency(\.networking.database).wrappedValue
        )

        async let getConversationValues: [String: Any] = database.wrappedValue.getValues(
            at: NetworkPath.conversations.rawValue
        )

        async let getMessageValues: [String: Any] = database.wrappedValue.getValues(
            at: NetworkPath.messages.rawValue
        )

        async let getUserValues: [String: Any] = database.wrappedValue.getValues(
            at: NetworkPath.users.rawValue
        )

        let conversationData: [String: Any]
        let messageData: [String: Any]
        let userData: [String: Any]
        do {
            conversationData = try await getConversationValues
            messageData = try await getMessageValues
            userData = try await getUserValues
        } catch let error as Exception {
            throw error
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }

        let expiryThreshold: Duration = .seconds(300)

        for (key, value) in conversationData {
            CoreDatabaseStore.addValue(
                .init(
                    data: value,
                    expiresAfter: expiryThreshold
                ),
                forKey: [
                    Networking.config.environment.shortString,
                    NetworkPath.conversations.rawValue,
                    key,
                ].joined(separator: "/")
            )
        }

        for (key, value) in messageData {
            CoreDatabaseStore.addValue(
                .init(
                    data: value,
                    expiresAfter: expiryThreshold
                ),
                forKey: [
                    Networking.config.environment.shortString,
                    NetworkPath.messages.rawValue,
                    key,
                ].joined(separator: "/")
            )
        }

        for (key, value) in userData {
            CoreDatabaseStore.addValue(
                .init(
                    data: value,
                    expiresAfter: expiryThreshold
                ),
                forKey: [
                    Networking.config.environment.shortString,
                    NetworkPath.users.rawValue,
                    key,
                ].joined(separator: "/")
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

        RuntimeStorage.store(
            true,
            as: .populatedTemporaryCaches
        )
    }

    func withGlobalCacheStrategy<T: Sendable>(
        _ strategy: CacheStrategy,
        perform body: @Sendable () async throws -> T
    ) async throws -> T {
        setGlobalCacheStrategy(strategy)
        defer { setGlobalCacheStrategy(nil) }
        return try await body()
    }
}
