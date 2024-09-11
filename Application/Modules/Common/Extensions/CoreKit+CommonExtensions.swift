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

    func destroyConversationDatabase() async -> Exception? {
        @Dependency(\.networking) var networking: Networking

        let getValuesResult = await networking.database.getValues(at: networking.config.paths.users)

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .typecastFailed("dictionary", metadata: [self, #file, #function, #line])
            }

            let userIDs = Array(dictionary.keys)
            for userID in userIDs {
                if let exception = await networking.database.setValue(
                    [String.bangQualifiedEmpty],
                    forKey: "\(networking.config.paths.users)/\(userID)/\(User.SerializationKeys.conversationIDs.rawValue)"
                ) {
                    return exception
                }
            }

            for keyPath in [networking.config.paths.conversations, networking.config.paths.messages] {
                if let exception = await networking.database.setValue(
                    NSNull(),
                    forKey: keyPath
                ) {
                    return exception
                }
            }

            // TODO: Rewrite to delete all audio message inputs.
//            if let exception = await networking.storage.deleteItem(at: networking.config.paths.audioMessageInputs) {
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
        @Dependency(\.networking) var networking: Networking

        let getValuesResult = await networking.database.getValues(at: networking.config.paths.users)

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                return .typecastFailed("dictionary", metadata: [self, #file, #function, #line])
            }

            let userIDs = Array(dictionary.keys)
            for userID in userIDs {
                if let exception = await networking.database.setValue(
                    [String.bangQualifiedEmpty],
                    forKey: "\(networking.config.paths.users)/\(userID)/\(User.SerializationKeys.pushTokens.rawValue)"
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
