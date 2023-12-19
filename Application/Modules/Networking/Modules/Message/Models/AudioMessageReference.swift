//
//  AudioMessageReference.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct AudioMessageReference: Codable, Equatable {
    // MARK: - Properties

    // AudioFile
    public let original: AudioFile
    public let translated: AudioFile

    // String
    public let originalDirectoryPath: String
    public let targetLanguageCode: String
    public let translatedDirectoryPath: String

    // MARK: - Init

    public init(
        _ targetLanguageCode: String,
        original: AudioFile,
        originalDirectoryPath: String,
        translated: AudioFile,
        translatedDirectoryPath: String
    ) {
        self.targetLanguageCode = targetLanguageCode
        self.original = original
        self.originalDirectoryPath = originalDirectoryPath
        self.translated = translated
        self.translatedDirectoryPath = translatedDirectoryPath
    }
}
