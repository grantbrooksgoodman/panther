//
//  CoreUtilities+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux
import Translator

public extension CoreKit.Utilities {
    func clearCaches() {
        @Dependency(\.commonServices) var commonServices: CommonServices
        @Dependency(\.networking.services) var networkServices: NetworkServices

        commonServices.contact.contactPairArchive.clearArchive()
        networkServices.conversation.archive.clearArchive()
        networkServices.user.archive.clearArchive()
        TranslationArchiver.clearArchive()

        commonServices.contact.clearCache()
        commonServices.propertyLists.clearCache()
        commonServices.regionDetail.clearCache()
        networkServices.user.clearCache()
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
}
