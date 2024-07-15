//
//  MediaFile.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public struct MediaFile: Codable, Equatable {
    // MARK: - Properties

    public let fileExtension: MediaFileExtension
    public let name: String
    public let urlPath: URL

    // MARK: - Computed Properties

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
