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

struct LocalMediaFilePath: Codable, Equatable {
    // MARK: - Properties

    let relativePathString: String
    let relativeThumbnailPathString: String?

    // MARK: - Computed Properties

    var localPathURL: URL {
        @Dependency(\.fileManager) var fileManager: FileManager
        return fileManager.documentsDirectoryURL.appending(path: relativePathString)
    }

    var localThumbnailPathURL: URL? {
        @Dependency(\.fileManager) var fileManager: FileManager
        guard let relativeThumbnailPathString else { return nil }
        return fileManager.documentsDirectoryURL.appending(path: relativeThumbnailPathString)
    }

    // MARK: - Init

    init(
        relativePathString: String,
        relativeThumbnailPathString: String? = nil,
    ) {
        self.relativePathString = relativePathString
        self.relativeThumbnailPathString = relativeThumbnailPathString
    }

    init?(contentType: HostedContentType) {
        switch contentType {
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

    init?(_ message: Message) {
        self.init(contentType: message.contentType)
    }
}
