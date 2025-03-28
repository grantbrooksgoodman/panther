//
//  CoreKit+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem
import Networking

public extension CoreKit.GCD {
    var newSerialQueue: DispatchQueue {
        let label = "\(Int.random(in: 1 ... 1_000_000))"
        Logger.log(
            "Instantiating new queue with label «\(label)».",
            domain: .queue,
            metadata: [self, #file, #function, #line]
        )
        return .init(label: label, qos: .userInteractive)
    }
}

public extension CoreKit.Utilities {
    // MARK: - Methods

    @MainActor
    func deleteConversationsForCurrentUser() async -> Exception? {
        @Dependency(\.networking) var networking: NetworkServices
        @Dependency(\.clientSession.user.currentUser?.conversationIDs) var conversationIDs: [ConversationID]?
        @Dependency(\.uiApplication) var uiApplication: UIApplication

        guard let conversationIDs,
              !conversationIDs.isEmpty else {
            return .init(
                "Current user has no open conversations.",
                metadata: [self, #file, #function, #line]
            )
        }

        uiApplication.mainWindow?.addOverlay(
            alpha: 0.5,
            activityIndicator: (.large, .white)
        )

        defer {
            networking.database.setGlobalCacheStrategy(nil)
            networking.storage.setGlobalCacheStrategy(nil)
            uiApplication.mainWindow?.removeOverlay()
        }

        networking.database.setGlobalCacheStrategy(.disregardCache)
        networking.storage.setGlobalCacheStrategy(.disregardCache)

        for conversationIDKey in conversationIDs.map(\.key) {
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
        @Dependency(\.networking) var networking: NetworkServices

        let getValuesResult = await networking.database.getValues(at: NetworkPath.users.rawValue)

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .Networking.typecastFailed("dictionary", metadata: [self, #file, #function, #line])
            }

            let userIDs = Array(dictionary.keys)
            for userID in userIDs {
                if let exception = await networking.database.setValue(
                    [String.bangQualifiedEmpty],
                    forKey: "\(NetworkPath.users)/\(userID)/\(User.SerializationKeys.conversationIDs.rawValue)"
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

            // TODO: Rewrite to delete all audio message inputs.
//            if let exception = await networking.storage.deleteItem(at: NetworkPath.audioMessageInputs) {
//                return exception
//            }

        case let .failure(exception):
            return exception
        }

        return nil
    }

    @discardableResult
    func eraseDocumentsDirectory() -> Exception? {
        @Dependency(\.fileManager) var fileManager: FileManager

        do {
            let filePaths = try fileManager.contentsOfDirectory(at: fileManager.documentsDirectoryURL, includingPropertiesForKeys: nil)
            for path in filePaths {
                try fileManager.removeItem(at: path)
            }
        } catch {
            return .init(error, metadata: [self, #file, #function, #line])
        }

        return nil
    }

    @discardableResult
    func eraseTemporaryDirectory() -> Exception? {
        @Dependency(\.fileManager) var fileManager: FileManager

        do {
            let filePaths = try fileManager.contentsOfDirectory(at: fileManager.temporaryDirectory, includingPropertiesForKeys: nil)
            for path in filePaths {
                try fileManager.removeItem(at: path)
            }
        } catch {
            return .init(error, metadata: [self, #file, #function, #line])
        }

        return nil
    }

    func resetPushTokens() async -> Exception? {
        @Dependency(\.networking) var networking: NetworkServices

        let getValuesResult = await networking.database.getValues(at: NetworkPath.users.rawValue)

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .Networking.typecastFailed("dictionary", metadata: [self, #file, #function, #line])
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
