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
            let directory = documentsDirectoryURL.appending(path: "\(name.removingPercentEncoding ?? name)/")
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

        if path.absoluteString.contains(documentsDirectoryURL.absoluteString),
           let documentsIndex = pathComponents.firstIndex(of: "Documents"),
           documentsIndex != pathComponents.count - 1 {
            let directoryComponents = pathComponents[documentsIndex + 1 ... pathComponents.count - 2]
            let newDirectories = directoryComponents.joined(separator: "/")
            if let exception = createDirectoryIfNeeded(newDirectories.removingPercentEncoding ?? newDirectories) {
                Logger.log(exception)
            }
        } else if pathComponents.count > 1 {
            let parentDirectory = pathComponents[pathComponents.count - 2]
            if let exception = createDirectoryIfNeeded(parentDirectory.removingPercentEncoding ?? parentDirectory) {
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
