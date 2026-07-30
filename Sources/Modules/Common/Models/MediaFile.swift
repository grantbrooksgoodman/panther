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

struct MediaFile: Codable, EncodedHashable, Hashable {
    // MARK: - Properties

    let fileExtension: MediaFileExtension
    let name: String
    let relativePath: String

    private static let contentHashes = LockIsolated([String: String]())

    // MARK: - Computed Properties

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

    var hasThumbnail: Bool {
        @Dependency(\.fileManager) var fileManager: FileManager
        guard let thumbnailPath = localPathURL.thumbnailPath else { return false }
        return fileManager.fileExists(atPath: thumbnailPath.path())
    }

    var localPathURL: URL {
        @Dependency(\.fileManager) var fileManager: FileManager
        return fileManager.documentsDirectoryURL.appending(path: relativePath)
    }

    // MARK: - Init

    init(
        _ relativePath: String,
        name: String,
        fileExtension: MediaFileExtension
    ) {
        self.relativePath = relativePath
        self.name = name
        self.fileExtension = fileExtension
    }

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
