//
//  LocalImageFilePath.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public struct LocalImageFilePath: Codable, Equatable {
    // MARK: - Properties

    public let filePathString: String
    public let filePathURL: URL

    // MARK: - Init

    public init(filePathString: String, filePathURL: URL) {
        self.filePathString = filePathString
        self.filePathURL = filePathURL
    }

    public init?(_ message: Message) {
        @Dependency(\.fileManager) var fileManager: FileManager
        @Dependency(\.networking.config.paths) var networkPaths: NetworkPaths

        guard message.contentType == .image else { return nil }

        let filePathString = "\(networkPaths.images)/\(message.id).\(MediaFileExtension.image(.png).rawValue)"
        let filePathURL = fileManager.documentsDirectoryURL.appending(path: filePathString)

        self.init(
            filePathString: filePathString,
            filePathURL: filePathURL
        )
    }
}
