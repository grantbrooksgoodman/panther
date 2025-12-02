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

struct LocalAudioFilePath: Codable, Equatable {
    // MARK: - Properties

    let inputFilePathString: String
    let inputFilePathURL: URL
    let outputDirectoryPathString: String
    let outputFilePathString: String
    let outputFilePathURL: URL

    // MARK: - Init

    init(
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

    init?(_ message: Message) {
        @Dependency(\.fileManager) var fileManager: FileManager

        guard message.contentType.isAudio,
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
