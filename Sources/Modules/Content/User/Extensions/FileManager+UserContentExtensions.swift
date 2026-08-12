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

extension FileManager {
    /// Copies the file at the given URL to the given path.
    ///
    /// - Parameters:
    ///   - url: The URL of the file to copy.
    ///   - path: The destination path.
    ///
    /// - Throws: An `Exception` if reading or writing the file fails.
    func copy(
        fileAt url: URL,
        toPath path: URL
    ) throws(Exception) {
        do {
            try createFile(
                atPath: path,
                data: Data.fromURL(url)
            )
        } catch {
            throw error
        }
    }

    /// Creates a file with the given data at the given path, creating intermediate directories as
    /// needed.
    ///
    /// - Parameters:
    ///   - path: The path at which to create the file. Its final component must include an
    ///     extension.
    ///   - data: The data to write.
    ///
    /// - Throws: An `Exception` if the path has no extension or writing the file fails.
    func createFile(
        atPath path: URL,
        data: Data
    ) throws(Exception) {
        func createDirectoryIfNeeded(_ name: String) throws(Exception) {
            let directory = documentsDirectoryURL.appending(path: "\(name.removingPercentEncoding ?? name)/")
            do {
                try createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                throw Exception(
                    error,
                    metadata: .init(sender: self)
                )
            }
        }

        let pathComponents = path.absoluteString.components(separatedBy: "/")
        guard let lastComponent = pathComponents.last,
              lastComponent.contains(".") else {
            throw Exception(
                "Cannot create file with no extension.",
                metadata: .init(sender: self)
            )
        }

        if path.absoluteString.contains(documentsDirectoryURL.absoluteString),
           let documentsIndex = pathComponents.firstIndex(of: "Documents"),
           pathComponents.count > documentsIndex + 1,
           pathComponents.count - 2 > 0,
           (documentsIndex + 1) < (pathComponents.count - 2) {
            let directoryComponents = pathComponents[documentsIndex + 1 ... pathComponents.count - 2]
            let newDirectories = directoryComponents.joined(separator: "/")
            do {
                try createDirectoryIfNeeded(
                    newDirectories.removingPercentEncoding ?? newDirectories
                )
            } catch {
                Logger.log(error)
            }
        } else if pathComponents.count > 1,
                  let parentDirectory = pathComponents.itemAt(pathComponents.count - 2) {
            do {
                try createDirectoryIfNeeded(
                    parentDirectory.removingPercentEncoding ?? parentDirectory
                )
            } catch {
                Logger.log(error)
            }
        }

        do {
            try data.write(to: path)
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }
    }

    /// Moves the file at the given URL to the given path.
    ///
    /// - Parameters:
    ///   - url: The URL of the file to move.
    ///   - path: The destination path.
    ///
    /// - Throws: An `Exception` if copying or removing the file fails.
    func move(
        fileAt url: URL,
        toPath path: URL
    ) throws(Exception) {
        try copy(
            fileAt: url,
            toPath: path
        )

        do {
            try removeItem(at: url)
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }
    }
}
