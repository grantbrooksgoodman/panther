//
//  MediaFile.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import CryptoKit
import Foundation

/* Proprietary */
import AppSubsystem

/// A media file stored in the app's documents directory.
///
/// A media file locates its content by ``relativePath``, resolved against the documents
/// directory, so values remain valid across app launches even though the directory's absolute
/// location can change. The file's identity derives from its extension and a hash of its content
/// on disk.
struct MediaFile: Codable, EncodedHashable, Hashable {
    // MARK: - Properties

    /// The file's extension.
    let fileExtension: MediaFileExtension

    /// The file's name, without an extension.
    let name: String

    /// The file's path, relative to the documents directory.
    let relativePath: String

    private static let contentHashes = LockIsolated([String: String]())

    // MARK: - Computed Properties

    /// The strings that collectively define this instance's identity for hashing purposes,
    /// sorted alphabetically.
    ///
    /// Contains the file extension's raw value and a hash of the file's content. If the content
    /// cannot be read, the content hash is omitted and the failure is logged.
    var hashFactors: [String] {
        var factors = [fileExtension.rawValue]

        do {
            try factors.append(
                Self.contentHash(forFileAt: localPathURL)
            )
        } catch {
            Logger.log(error)
        }

        return factors.sorted()
    }

    /// A Boolean value that indicates whether a thumbnail exists on disk for this file.
    var hasThumbnail: Bool {
        @Dependency(\.fileManager) var fileManager: FileManager
        guard let thumbnailPath = localPathURL.thumbnailPath else { return false }
        return fileManager.fileExists(atPath: thumbnailPath.path())
    }

    /// The absolute URL of the file, resolved against the current documents directory.
    var localPathURL: URL {
        @Dependency(\.fileManager) var fileManager: FileManager
        return fileManager.documentsDirectoryURL.appending(path: relativePath)
    }

    // MARK: - Init

    /// Creates a media file with the given relative path, name, and extension.
    ///
    /// - Parameters:
    ///   - relativePath: The file's path, relative to the documents directory.
    ///   - name: The file's name, without an extension.
    ///   - fileExtension: The file's extension.
    init(
        _ relativePath: String,
        name: String,
        fileExtension: MediaFileExtension
    ) {
        self.relativePath = relativePath
        self.name = name
        self.fileExtension = fileExtension
    }

    /// Creates a media file from the given relative path, deriving its name and extension.
    ///
    /// - Parameter relativePath: The file's path, relative to the documents directory. The
    ///   path's final component must consist of a name and a supported extension.
    ///
    /// - Returns: A media file, or `nil` if no file exists at the path or its name and extension
    ///   cannot be derived.
    init?(_ relativePath: String) {
        @Dependency(\.fileManager) var fileManager: FileManager

        let localPathURL = fileManager.documentsDirectoryURL.appending(path: relativePath)
        guard fileManager.fileExists(atPath: localPathURL.path()) || fileManager.fileExists(atPath: localPathURL.path(percentEncoded: false)),
              let fileName = relativePath.components(separatedBy: "/").last,
              fileName.components(separatedBy: ".").count == 2 else { return nil }

        let components = fileName.components(separatedBy: ".")
        guard let fileExtensionString = components.itemAt(1),
              let fileExtension = MediaFileExtension(fileExtensionString) else { return nil }

        self.init(
            relativePath,
            name: components[0],
            fileExtension: fileExtension
        )
    }

    // MARK: - Hashable Conformance

    /// Hashes the file's ``hashFactors``.
    func hash(into hasher: inout Hasher) {
        hasher.combine(hashFactors)
    }

    // MARK: - Auxiliary

    /// Files at these paths are effectively immutable once written,
    /// so a path + size + modification date key is sufficient; a
    /// changed file produces a new key.
    private static func contentHash(forFileAt url: URL) throws(Exception) -> String {
        @Dependency(\.fileManager) var fileManager: FileManager

        var cacheKey: String?
        if let attributes = try? fileManager.attributesOfItem(atPath: url.path(percentEncoded: false)),
           let fileSize = attributes[.size] as? Int,
           let modificationDate = attributes[.modificationDate] as? Date {
            cacheKey = "\(url.path())|\(fileSize)|\(modificationDate.timeIntervalSince1970)"
        }

        if let cacheKey,
           let contentHash = contentHashes.wrappedValue[cacheKey] {
            return contentHash
        }

        let contentHash = try Data.fromURL(url).hash
        if let cacheKey {
            contentHashes.wrappedValue[cacheKey] = contentHash
        }

        return contentHash
    }
}

private extension Data {
    var hash: String {
        .init(
            SHA256
                .hash(data: self)
                .compactMap { String(format: "%02x", $0) }
                .joined()
        )
    }
}
