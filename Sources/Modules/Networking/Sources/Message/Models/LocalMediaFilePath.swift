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

/// The local file paths for a media message's content.
struct LocalMediaFilePath: Codable, Equatable {
    // MARK: - Properties

    /// The media file's path, relative to the documents directory.
    let relativePathString: String

    /// The thumbnail's path, relative to the documents directory, or `nil` if there is no
    /// thumbnail.
    let relativeThumbnailPathString: String?

    // MARK: - Computed Properties

    /// The absolute URL of the media file.
    var localPathURL: URL {
        @Dependency(\.fileManager) var fileManager: FileManager
        return fileManager.documentsDirectoryURL.appending(path: relativePathString)
    }

    /// The absolute URL of the thumbnail, or `nil` if there is no thumbnail.
    var localThumbnailPathURL: URL? {
        @Dependency(\.fileManager) var fileManager: FileManager
        guard let relativeThumbnailPathString else { return nil }
        return fileManager.documentsDirectoryURL.appending(path: relativeThumbnailPathString)
    }

    // MARK: - Init

    /// Creates a media file path with the given relative paths.
    ///
    /// - Parameters:
    ///   - relativePathString: The media file's path, relative to the documents directory.
    ///   - relativeThumbnailPathString: The thumbnail's path, relative to the documents
    ///     directory, or `nil` if there is no thumbnail.
    init(
        relativePathString: String,
        relativeThumbnailPathString: String? = nil
    ) {
        self.relativePathString = relativePathString
        self.relativeThumbnailPathString = relativeThumbnailPathString
    }

    /// Creates a media file path from the given content type.
    ///
    /// - Parameter contentType: The content type to derive the paths from.
    ///
    /// - Returns: A media file path, or `nil` if the content type is not media.
    init?(contentType: HostedContentType) {
        switch contentType {
        case let .media(id: fileID, extension: fileExtension):
            let pathPrefix = "\(NetworkPath.media.rawValue)/\(fileID)"
            let filePath = "\(pathPrefix).\(fileExtension.rawValue)"
            let thumbnailPath = "\(pathPrefix)\(MediaFile.thumbnailImageNameSuffix)"

            self.init(
                relativePathString: filePath,
                relativeThumbnailPathString: (fileExtension.isDocument || fileExtension.isVideo) ? thumbnailPath : nil
            )

        default: return nil
        }
    }

    /// Creates a media file path from the given message.
    ///
    /// - Parameter message: The message to derive the paths from.
    ///
    /// - Returns: A media file path, or `nil` if the message is not a media message.
    init?(_ message: Message) {
        self.init(contentType: message.contentType)
    }
}
