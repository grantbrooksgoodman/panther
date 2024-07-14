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

    public let networkPathString: String
    public let localPathURL: URL

    // MARK: - Init

    public init(networkPathString: String, localPathURL: URL) {
        self.networkPathString = networkPathString
        self.localPathURL = localPathURL
    }

    public init?(_ message: Message) {
        @Dependency(\.fileManager) var fileManager: FileManager
        @Dependency(\.networking.config.paths) var networkPaths: NetworkPaths

        guard message.contentType == .media else { return nil }

        let networkPathString = "\(networkPaths.media)/\(message.id).\(MediaFileExtension.image(.png).rawValue)"
        let localPathURL = fileManager.documentsDirectoryURL.appending(path: networkPathString)

        self.init(
            networkPathString: networkPathString,
            localPathURL: localPathURL
        )
    }
}
