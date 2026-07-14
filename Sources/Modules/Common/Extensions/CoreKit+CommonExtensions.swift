//
//  CoreKit+CommonExtensions.swift
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

extension CoreKit.Utilities {
    // MARK: - Types

    enum ConversationDeletionGranularity {
        case allForCurrentUser
        case groupChatsWithoutNameOrPhoto
        case messageRecipientConsentEnabled
        case notVisibleForCurrentUser
        case oneToOneAndFewerThanFiveMessages
        case penPals
    }

    // MARK: - Methods

    func clearPreviousLanguageCodes() async throws(Exception) {
        @Dependency(\.networking.database) var database: DatabaseDelegate
        guard let currentUserID = User.currentUserID else {
            throw Exception(
                "Current user ID has not been set.",
                metadata: .init(sender: self)
            )
        }

        try await database.setValue(
            Array.bangQualifiedEmpty,
            forKey: [
                NetworkPath.users.rawValue,
                currentUserID,
                User.SerializableKey.previousLanguageCodes.rawValue,
            ].joined(separator: "/")
        )
    }

    @MainActor
    func deleteConversations(
        _ granularity: ConversationDeletionGranularity
    ) async throws(Exception) {
        @Dependency(\.clientSession) var clientSession: ClientSession
        @Dependency(\.coreKit.ui) var coreUI: CoreKit.UI
        @Dependency(\.networking) var networking: NetworkServices

        try await clientSession.user.resolveCurrentUser(
            and: [
                .conversations,
                .messages,
            ]
        )

        let currentUser = clientSession.user.currentUser
        var conversationIDKeys: [String]?

        let ignoredConversationIDKeys = clientSession.store.ignoredConversationIDKeys

        switch granularity {
        case .allForCurrentUser:
            conversationIDKeys = currentUser?.conversationIDs?.map(\.key)
            conversationIDKeys?.append(contentsOf: ignoredConversationIDKeys)

        case .groupChatsWithoutNameOrPhoto:
            conversationIDKeys = currentUser?.conversations?.filter {
                $0.metadata.name.isBangQualifiedEmpty &&
                    $0.metadata.imageData == nil &&
                    !$0.metadata.isPenPalsConversation &&
                    $0.participants.count > 2
            }.map(\.id.key)

        case .messageRecipientConsentEnabled:
            conversationIDKeys = currentUser?.conversations?.filter {
                $0.didSendConsentMessage ||
                    $0.messages?.contains(where: \.isConsentMessage) == true ||
                    $0.metadata.requiresConsentFromInitiator != nil
            }.map(\.id.key)

        case .notVisibleForCurrentUser:
            guard let invisibleConversationIDKeys = currentUser?
                .conversations?
                .filter({ !$0.isVisibleForCurrentUser })
                .map(\.id.key) else { return }

            conversationIDKeys = invisibleConversationIDKeys
            conversationIDKeys?.append(contentsOf: ignoredConversationIDKeys)

        case .oneToOneAndFewerThanFiveMessages:
            conversationIDKeys = currentUser?.conversations?.filter {
                $0.messageIDs.count < 5 &&
                    $0.participants.count == 2
            }.map(\.id.key)

        case .penPals:
            conversationIDKeys = currentUser?.conversations?
                .filter(\.metadata.isPenPalsConversation)
                .map(\.id.key)
        }

        guard let conversationIDKeys else {
            throw Exception(
                "Failed to resolve conversation ID keys.",
                metadata: .init(sender: self)
            )
        }

        defer {
            networking.database.setGlobalCacheStrategy(nil)
            networking.storage.setGlobalCacheStrategy(nil)
            coreUI.removeOverlay()
        }

        coreUI.addOverlay(
            alpha: 0.5,
            activityIndicator: .largeWhite
        )

        networking.database.setGlobalCacheStrategy(.disregardCache)
        networking.storage.setGlobalCacheStrategy(.disregardCache)

        clientSession.user.stopObservingCurrentUserChanges(
            disableChangeEmission: true
        )

        var exceptions = [Exception]()
        for conversationIDKey in conversationIDKeys.unique {
            CoreDatabaseStore.clearStore()
            try await networking.integrityService.resolveSession()

            if let exception = await networking
                .integrityService
                .repairMalformedConversations([conversationIDKey])
                .exception {
                exceptions.append(exception)
            }
        }

        guard let exception = exceptions.compiledException else { return }
        throw exception
    }

    @MainActor
    func destroyConversationDatabase() async throws(Exception) {
        @Dependency(\.coreKit.ui) var coreUI: CoreKit.UI
        @Dependency(\.networking) var networking: NetworkServices

        coreUI.addOverlay(
            alpha: 0.5,
            activityIndicator: .largeWhite
        )

        defer {
            networking.database.setGlobalCacheStrategy(nil)
            networking.storage.setGlobalCacheStrategy(nil)
            coreUI.removeOverlay()
        }

        networking.database.setGlobalCacheStrategy(.disregardCache)
        networking.storage.setGlobalCacheStrategy(.disregardCache)

        let userData: [String: Any] = try await networking.database.getValues(
            at: NetworkPath.users.rawValue
        )

        let userIDs = Array(userData.keys)
        let database = LockIsolated(networking.database)
        try await userIDs.map { @Sendable in
            try await database.wrappedValue.setValue(
                [String.bangQualifiedEmpty],
                forKey: [
                    NetworkPath.users.rawValue,
                    $0,
                    User.SerializableKey.conversationIDs.rawValue,
                ].joined(separator: "/")
            )
        }

        for keyPath in [
            NetworkPath.conversations.rawValue,
            NetworkPath.messages.rawValue,
        ] {
            try await networking.database.setValue(
                NSNull(),
                forKey: keyPath
            )
        }

        if await (try? networking.storage.itemExists(
            as: .directory,
            at: NetworkPath.audioMessageInputs.rawValue
        )) == true {
            try await networking.storage.deleteAllItems(
                at: NetworkPath.audioMessageInputs.rawValue,
                includeItemsInSubdirectories: true,
                timeout: .seconds(600)
            )
        }

        if await (try? networking.storage.itemExists(
            as: .directory,
            at: NetworkPath.media.rawValue
        )) == true {
            try await networking.storage.deleteAllItems(
                at: NetworkPath.media.rawValue,
                includeItemsInSubdirectories: true,
                timeout: .seconds(600)
            )
        }
    }

    func resetPushTokens() async throws(Exception) {
        @Dependency(\.networking) var networking: NetworkServices

        let userData: [String: Any] = try await networking.database.getValues(
            at: NetworkPath.users.rawValue
        )

        let userIDs = Array(userData.keys)
        let database = LockIsolated(networking.database)
        try await userIDs.map { @Sendable in
            try await database.wrappedValue.setValue(
                [String.bangQualifiedEmpty],
                forKey: [
                    NetworkPath.users.rawValue,
                    $0,
                    User.SerializableKey.pushTokens.rawValue,
                ].joined(separator: "/")
            )
        }
    }
}
