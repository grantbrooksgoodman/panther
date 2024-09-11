//
//  FileManager+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 13/07/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension FileManager {
    func createFile(
        atPath path: URL,
        data: Data
    ) -> Exception? {
        func createDirectoryIfNeeded(_ name: String) -> Exception? {
            let directory = documentsDirectoryURL.appending(path: "\(name)/")
            do {
                try createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                return .init(error, metadata: [self, #file, #function, #line])
            }
            return nil
        }

        let pathComponents = path.absoluteString.components(separatedBy: "/")
        guard let lastComponent = pathComponents.last,
              lastComponent.contains(".") else {
            return .init(
                "Cannot create file with no extension.",
                metadata: [self, #file, #function, #line]
            )
        }

        if pathComponents.count > 1 {
            let parentDirectory = pathComponents[pathComponents.count - 2]
            if let exception = createDirectoryIfNeeded(parentDirectory) {
                Logger.log(exception)
            }
        }

        do {
            try data.write(to: path)
        } catch {
            return .init(error, metadata: [self, #file, #function, #line])
        }

        return nil
    }
}
