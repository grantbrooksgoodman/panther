//
//  LocalAudioFilePath.swift
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

public struct LocalAudioFilePath: Codable, Equatable {
    // MARK: - Properties

    // String
    public let inputFilePathString: String
    public let outputDirectoryPathString: String
    public let outputFilePathString: String

    // URL
    public let inputFilePathURL: URL
    public let outputFilePathURL: URL

    // MARK: - Init

    public init(
        inputFilePathString: String,
        inputFilePathURL: URL,
        outputDirectoryPathString: String,
        outputFilePathString: String,
        outputFilePathURL: URL
    ) {
        self.inputFilePathString = inputFilePathString
        self.inputFilePathURL = inputFilePathURL
        self.outputDirectoryPathString = outputDirectoryPathString
        self.outputFilePathString = outputFilePathString
        self.outputFilePathURL = outputFilePathURL
    }

    public init?(_ message: Message) {
        @Dependency(\.fileManager) var fileManager: FileManager

        guard message.contentType == .audio,
              let translation = message.translation else { return nil }

        let inputFilePath = "\(NetworkPath.audioMessageInputs.rawValue)/\(message.id).\(MediaFileExtension.audio(.m4a).rawValue)"
        let outputDirectoryPath = "\(NetworkPath.audioTranslations.rawValue)/\(translation.reference.hostingKey)/"
        var outputFilePath = outputDirectoryPath + "\(translation.languagePair.to)-\(AudioService.FileNames.outputM4A)"
        if translation.languagePair.isIdempotent {
            outputFilePath = inputFilePath
        }

        let inputFileURL = fileManager.documentsDirectoryURL.appending(path: inputFilePath)
        let outputFileURL = fileManager.documentsDirectoryURL.appending(path: outputFilePath)

        self.init(
            inputFilePathString: inputFilePath,
            inputFilePathURL: inputFileURL,
            outputDirectoryPathString: outputDirectoryPath,
            outputFilePathString: outputFilePath,
            outputFilePathURL: outputFileURL
        )
    }
}
