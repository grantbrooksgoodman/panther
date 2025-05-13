//
//  LocalMediaFilePath.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

public struct LocalMediaFilePath: Codable, Equatable {
    // MARK: - Properties

    public let relativePathString: String
    public let relativeThumbnailPathString: String?

    // MARK: - Computed Properties

    public var localPathURL: URL {
        @Dependency(\.fileManager) var fileManager: FileManager
        return fileManager.documentsDirectoryURL.appending(path: relativePathString)
    }

    public var localThumbnailPathURL: URL? {
        @Dependency(\.fileManager) var fileManager: FileManager
        guard let relativeThumbnailPathString else { return nil }
        return fileManager.documentsDirectoryURL.appending(path: relativeThumbnailPathString)
    }

    // MARK: - Init

    public init(
        relativePathString: String,
        relativeThumbnailPathString: String? = nil,
    ) {
        self.relativePathString = relativePathString
        self.relativeThumbnailPathString = relativeThumbnailPathString
    }

    public init?(_ message: Message) {
        switch message.contentType {
        case let .media(id: fileID, extension: fileExtension):
            let pathPrefix = "\(NetworkPath.media.rawValue)/\(fileID)"
            let filePath = "\(pathPrefix).\(fileExtension.rawValue)"
            let thumbnailPath = "\(pathPrefix)\(MediaFile.thumbnailImageNameSuffix)"

            let thumbnailMediaFileExtensions = [
                MediaFileExtension.document(.pdf),
                MediaFileExtension.video(.mp4),
            ]

            self.init(
                relativePathString: filePath,
                relativeThumbnailPathString: thumbnailMediaFileExtensions.contains(fileExtension) ? thumbnailPath : nil
            )

        default: return nil
        }
    }
}
