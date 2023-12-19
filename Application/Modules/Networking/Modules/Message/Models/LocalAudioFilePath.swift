//
//  LocalAudioFilePath.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public struct LocalAudioFilePath: Codable, Equatable {
    // MARK: - Properties

    // String
    public let inputDirectoryPathString: String
    public let inputFilePathString: String
    public let outputDirectoryPathString: String
    public let outputFilePathString: String

    // URL
    public let inputFilePathURL: URL
    public let outputFilePathURL: URL

    // MARK: - Init

    public init(
        inputDirectoryPathString: String,
        inputFilePathString: String,
        inputFilePathURL: URL,
        outputDirectoryPathString: String,
        outputFilePathString: String,
        outputFilePathURL: URL
    ) {
        self.inputDirectoryPathString = inputDirectoryPathString
        self.inputFilePathString = inputFilePathString
        self.inputFilePathURL = inputFilePathURL
        self.outputDirectoryPathString = outputDirectoryPathString
        self.outputFilePathString = outputFilePathString
        self.outputFilePathURL = outputFilePathURL
    }

    public init?(_ message: Message) {
        @Dependency(\.fileManager) var fileManager: FileManager
        @Dependency(\.networking.config.paths) var networkPaths: NetworkPaths

        guard message.hasAudioComponent else { return nil }

        let inputFilePath = "\(networkPaths.audioMessageInputs)/\(message.id).\(AudioFileExtension.m4a.rawValue)"
        var outputFilePath = "\(networkPaths.audioTranslations)/\(message.translation.model.referenceKey)/\(AudioService.FileNames.outputM4A)"
        if message.translation.languagePair.isIdempotent {
            outputFilePath = inputFilePath
        }

        let inputFileURL = fileManager.documentsDirectoryURL.appending(path: inputFilePath)
        let outputFileURL = fileManager.documentsDirectoryURL.appending(path: outputFilePath)

        self.init(
            inputDirectoryPathString: networkPaths.audioMessageInputs,
            inputFilePathString: inputFilePath,
            inputFilePathURL: inputFileURL,
            outputDirectoryPathString: "\(networkPaths.audioTranslations)/\(message.translation.model.referenceKey)",
            outputFilePathString: outputFilePath,
            outputFilePathURL: outputFileURL
        )
    }
}
