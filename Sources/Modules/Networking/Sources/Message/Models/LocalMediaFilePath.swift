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

    // String
    public let networkPathString: String
    public let thumbnailNetworkPathString: String?

    // URL
    public let localPathURL: URL
    public let thumbnailLocalPathURL: URL?

    // MARK: - Init

    public init(
        networkPathString: String,
        localPathURL: URL,
        thumbnailNetworkPathString: String? = nil,
        thumbnailLocalPathURL: URL? = nil
    ) {
        self.networkPathString = networkPathString
        self.localPathURL = localPathURL
        self.thumbnailNetworkPathString = thumbnailNetworkPathString
        self.thumbnailLocalPathURL = thumbnailLocalPathURL
    }

    public init?(_ message: Message) {
        @Dependency(\.fileManager) var fileManager: FileManager

        switch message.contentType {
        case let .media(id: fileID, extension: fileExtension):
            let pathPrefix = "\(NetworkPath.media.rawValue)/\(fileID)"
            let networkPathString = "\(pathPrefix).\(fileExtension.rawValue)"
            let thumbnailNetworkPathString = "\(pathPrefix)\(MediaFile.thumbnailImageNameSuffix)"

            let localPathURL = fileManager.documentsDirectoryURL.appending(path: networkPathString)
            let thumbnailLocalPathURL = fileManager.documentsDirectoryURL.appending(path: thumbnailNetworkPathString)

            let thumbnailMediaFileExtensions = [
                MediaFileExtension.document(.pdf),
                MediaFileExtension.video(.mp4),
            ]

            guard thumbnailMediaFileExtensions.contains(fileExtension) else {
                self.init(
                    networkPathString: networkPathString,
                    localPathURL: localPathURL
                )
                return
            }

            self.init(
                networkPathString: networkPathString,
                localPathURL: localPathURL,
                thumbnailNetworkPathString: thumbnailNetworkPathString,
                thumbnailLocalPathURL: thumbnailLocalPathURL
            )

        default: return nil
        }
    }
}
