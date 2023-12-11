//
//  Message.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux
import Translator

public struct Message: Codable, CompressedHashable, Equatable {
    // MARK: - Properties

    // Date
    public let readDate: Date?
    public let sentDate: Date

    // String
    public let fromAccountID: String
    public let id: String

    // Other
    public let audioComponent: AudioMessageReference?
    public let hasAudioComponent: Bool
    public let languagePair: LanguagePair
    public let translation: Translation

    // MARK: - Computed Properties

    public var hashFactors: [String] {
        @Dependency(\.standardDateFormatter) var dateFormatter: DateFormatter
        var factors = [
            id,
            fromAccountID,
            hasAudioComponent.description,
            languagePair.asString(),
            dateFormatter.string(from: sentDate),
        ]

        if let readDate {
            factors.append(dateFormatter.string(from: readDate))
        }

        return factors
    }

    public var localAudioFilePath: LocalAudioFilePath? {
        @Dependency(\.fileManager) var fileManager: FileManager
        @Dependency(\.networking.config.environment) var networkEnvironment: NetworkEnvironment

        guard hasAudioComponent else { return nil }

        let path = "audioMessages/\(translation.languagePair.asString())/\(translation.serialized.key)"

        let inputFilePath = "\(path)/\(id).m4a"
        var outputFilePath = "\(path)/\(AudioService.FileNames.outputM4A)"
        if translation.languagePair.from == translation.languagePair.to {
            outputFilePath = inputFilePath
        }

        let inputFileURL = fileManager.documentsDirectoryURL.appending(path: inputFilePath)
        let outputFileURL = fileManager.documentsDirectoryURL.appending(path: outputFilePath)

        return .init(
            directoryPathString: path,
            inputPathString: inputFilePath,
            inputPathURL: inputFileURL,
            outputPathString: outputFilePath,
            outputPathURL: outputFileURL
        )
    }

    // MARK: - Init

    public init(
        _ id: String,
        fromAccountID: String,
        hasAudioComponent: Bool,
        audioComponent: AudioMessageReference?,
        languagePair: LanguagePair,
        translation: Translation,
        readDate: Date?,
        sentDate: Date
    ) {
        self.id = id
        self.fromAccountID = fromAccountID
        self.hasAudioComponent = hasAudioComponent
        self.audioComponent = audioComponent
        self.languagePair = languagePair
        self.translation = translation
        self.readDate = readDate
        self.sentDate = sentDate
    }
}
