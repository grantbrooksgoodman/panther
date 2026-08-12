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
import Translator

/// The local file paths for an audio message's input and translated output audio.
struct LocalAudioFilePath: Codable, Equatable {
    // MARK: - Properties

    /// The input recording's path, relative to the documents directory.
    let inputFilePathString: String

    /// The absolute URL of the input recording.
    let inputFilePathURL: URL

    /// The path to the directory containing the translated output audio.
    let outputDirectoryPathString: String

    /// The translated output audio's path, relative to the documents directory.
    let outputFilePathString: String

    /// The absolute URL of the translated output audio.
    let outputFilePathURL: URL

    // MARK: - Init

    /// Creates an audio file path with the given paths.
    ///
    /// - Parameters:
    ///   - inputFilePathString: The input recording's path, relative to the documents directory.
    ///   - inputFilePathURL: The absolute URL of the input recording.
    ///   - outputDirectoryPathString: The path to the directory containing the translated output
    ///     audio.
    ///   - outputFilePathString: The translated output audio's path, relative to the documents
    ///     directory.
    ///   - outputFilePathURL: The absolute URL of the translated output audio.
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

    /// Creates an audio file path for the given message and translation.
    ///
    /// For an idempotent translation, the output path matches the input path.
    ///
    /// - Parameters:
    ///   - messageID: The identifier of the message.
    ///   - translation: The translation to derive the output paths from.
    init(
        messageID: String,
        translation: Translation
    ) {
        @Dependency(\.fileManager) var fileManager: FileManager

        let inputFilePath = "\(NetworkPath.audioMessageInputs.rawValue)/\(messageID).\(MediaFileExtension.audio(.m4a).rawValue)"
        let outputDirectoryPath = [
            NetworkPath.audioTranslations.rawValue,
            translation.reference.hostingKey,
        ].joined(separator: "/")

        var outputFilePath = outputDirectoryPath + "/\(translation.languagePair.to)-\(AudioService.FileNames.outputM4A)"
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

    /// Creates an audio file path from the given message.
    ///
    /// - Parameter message: The message to derive the paths from.
    ///
    /// - Returns: An audio file path, or `nil` if the message is not an audio message or has no
    ///   translation.
    init?(_ message: Message) {
        guard message.contentType.isAudio,
              let translation = message.translation else { return nil }
        self.init(messageID: message.id, translation: translation)
    }
}
