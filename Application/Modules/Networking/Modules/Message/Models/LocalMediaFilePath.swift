//
//  LocalMediaFilePath.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

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

    public init?(_ message: Message) async {
        @Dependency(\.fileManager) var fileManager: FileManager
        @Dependency(\.networking.config.paths.media) var mediaPath: String

        let resolveMediaFileExtensionResult = await message.resolveMediaFileExtension(message.id)

        switch resolveMediaFileExtensionResult {
        case let .success(fileExtension):
            let pathPrefix = "\(mediaPath)/\(message.id)"
            let networkPathString = "\(pathPrefix).\(fileExtension)"
            let thumbnailNetworkPathString = "\(pathPrefix)\(MediaFile.thumbnailImageNameSuffix)"

            let localPathURL = fileManager.documentsDirectoryURL.appending(path: networkPathString)
            let thumbnailLocalPathURL = fileManager.documentsDirectoryURL.appending(path: thumbnailNetworkPathString)

            let thumbnailMediaFileExtensions = [
                MediaFileExtension.document(.pdf).rawValue,
                MediaFileExtension.video(.mp4).rawValue,
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

        case let .failure(exception):
            Logger.log(exception)
            return nil
        }
    }
}
