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

public struct MediaFile: Codable, EncodedHashable, Equatable {
    // MARK: - Properties

    public let fileExtension: MediaFileExtension
    public let name: String
    public let urlPath: URL

    // MARK: - Computed Properties

    public var hashFactors: [String] {
        var factors = [fileExtension.rawValue]

        let dataFromURLResult = Data.fromURL(urlPath)
        switch dataFromURLResult {
        case let .success(data): factors.append(data.hash)
        case let .failure(exception): Logger.log(exception, with: .toastInPrerelease)
        }

        return factors.sorted()
    }

    public var hasThumbnail: Bool {
        @Dependency(\.fileManager) var fileManager: FileManager
        guard let thumbnailPath = urlPath.thumbnailPath else { return false }
        return fileManager.fileExists(atPath: thumbnailPath.path())
    }

    // MARK: - Init

    public init(
        _ urlPath: URL,
        name: String,
        fileExtension: MediaFileExtension
    ) {
        self.urlPath = urlPath
        self.name = name
        self.fileExtension = fileExtension
    }

    public init?(_ url: URL) {
        @Dependency(\.fileManager) var fileManager: FileManager

        guard fileManager.fileExists(atPath: url.path()) || fileManager.fileExists(atPath: url.path(percentEncoded: false)),
              let fileName = url.absoluteString.components(separatedBy: "/").last,
              fileName.components(separatedBy: ".").count == 2 else { return nil }

        let components = fileName.components(separatedBy: ".")
        guard let fileExtensionString = components.itemAt(1),
              let fileExtension = MediaFileExtension(fileExtensionString) else { return nil }

        self.init(
            url,
            name: components[0],
            fileExtension: fileExtension
        )
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
