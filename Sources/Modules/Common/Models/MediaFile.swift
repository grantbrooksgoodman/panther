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

public struct MediaFile: Codable, EncodedHashable, Hashable {
    // MARK: - Properties

    public let fileExtension: MediaFileExtension
    public let name: String
    public let relativePath: String

    // MARK: - Computed Properties

    public var hashFactors: [String] {
        var factors = [fileExtension.rawValue]

        let dataFromURLResult = Data.fromURL(localPathURL)
        switch dataFromURLResult {
        case let .success(data): factors.append(data.hash)
        case let .failure(exception): Logger.log(exception, with: .toastInPrerelease)
        }

        return factors.sorted()
    }

    public var hasThumbnail: Bool {
        @Dependency(\.fileManager) var fileManager: FileManager
        guard let thumbnailPath = localPathURL.thumbnailPath else { return false }
        return fileManager.fileExists(atPath: thumbnailPath.path())
    }

    public var localPathURL: URL {
        @Dependency(\.fileManager) var fileManager: FileManager
        return fileManager.documentsDirectoryURL.appending(path: relativePath)
    }

    // MARK: - Init

    public init(
        _ relativePath: String,
        name: String,
        fileExtension: MediaFileExtension
    ) {
        self.relativePath = relativePath
        self.name = name
        self.fileExtension = fileExtension
    }

    public init?(_ relativePath: String) {
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

    public func hash(into hasher: inout Hasher) {
        hasher.combine(hashFactors)
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
