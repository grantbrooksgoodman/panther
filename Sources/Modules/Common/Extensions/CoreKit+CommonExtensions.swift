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

public extension CoreKit.GCD {
    var newSerialQueue: DispatchQueue {
        let label = "\(Int.random(in: 1 ... 1_000_000))"
        Logger.log(
            "Instantiating new queue with label «\(label)».",
            domain: .queue,
            sender: self
        )
        return .init(label: label, qos: .userInteractive)
    }
}

public extension CoreKit.Utilities {
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

    func clearPreviousLanguageCodes() async -> Exception? {
        @Dependency(\.networking.database) var database: DatabaseDelegate
        guard let currentUserID = User.currentUserID else {
            return .init(
                "Current user ID has not been set.",
                metadata: .init(sender: self)
            )
        }

        return await database.setValue(
            Array.bangQualifiedEmpty,
            forKey: "\(NetworkPath.users.rawValue)/\(currentUserID)/\(User.SerializationKeys.previousLanguageCodes.rawValue)",
        )
    }

    @MainActor
    func deleteConversations(_ granularity: ConversationDeletionGranularity) async -> Exception? {
        @Dependency(\.coreKit.ui) var coreUI: CoreKit.UI
        @Dependency(\.clientSession.user.currentUser) var currentUser: User?
        @Dependency(\.networking) var networking: NetworkServices

        if let exception = await currentUser?.setConversations() {
            return exception
        }

        var conversationIDKeys: [String]?

        switch granularity {
        case .allForCurrentUser:
            conversationIDKeys = currentUser?.conversationIDs?.map(\.key)

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
                .map(\.id.key) else { return nil }

            conversationIDKeys = invisibleConversationIDKeys

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
            return .init(
                "Failed to resolve conversation ID keys.",
                metadata: .init(sender: self)
            )
        }

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

        for conversationIDKey in conversationIDKeys {
            CoreDatabaseStore.clearStore()
            if let exception = await networking.integrityService.resolveSession() {
                return exception
            }

            if let exception = await networking.integrityService.repairMalformedConversations([conversationIDKey]).exception {
                return exception
            }
        }

        return nil
    }

    func destroyConversationDatabase() async -> Exception? {
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

        let getValuesResult = await networking.database.getValues(at: NetworkPath.users.rawValue)

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .Networking.typecastFailed("dictionary", metadata: .init(sender: self))
            }

            let userIDs = Array(dictionary.keys)
            for userID in userIDs {
                if let exception = await networking.database.setValue(
                    [String.bangQualifiedEmpty],
                    forKey: "\(NetworkPath.users.rawValue)/\(userID)/\(User.SerializationKeys.conversationIDs.rawValue)"
                ) {
                    return exception
                }
            }

            for keyPath in [NetworkPath.conversations.rawValue, NetworkPath.messages.rawValue] {
                if let exception = await networking.database.setValue(
                    NSNull(),
                    forKey: keyPath
                ) {
                    return exception
                }
            }

            if let exception = await networking.storage.deleteAllItems(
                at: NetworkPath.audioMessageInputs.rawValue,
                includeItemsInSubdirectories: true
            ) {
                return exception
            }

        case let .failure(exception):
            return exception
        }

        return nil
    }

    func resetPushTokens() async -> Exception? {
        @Dependency(\.networking) var networking: NetworkServices

        let getValuesResult = await networking.database.getValues(at: NetworkPath.users.rawValue)

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .Networking.typecastFailed("dictionary", metadata: .init(sender: self))
            }

            let userIDs = Array(dictionary.keys)
            for userID in userIDs {
                if let exception = await networking.database.setValue(
                    [String.bangQualifiedEmpty],
                    forKey: "\(NetworkPath.users.rawValue)/\(userID)/\(User.SerializationKeys.pushTokens.rawValue)"
                ) {
                    return exception
                }
            }

            return nil

        case let .failure(exception):
            return exception
        }
    }
}
