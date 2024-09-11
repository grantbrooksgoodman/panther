//
//  AudioMessageReference.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import Translator

public struct AudioMessageReference: Codable, Equatable {
    // MARK: - Properties

    // AudioFile
    public let original: AudioFile
    public let translated: AudioFile

    // String
    public let translatedDirectoryPath: String

    // Translation
    public let translation: Translation

    // MARK: - Init

    public init(
        translation: Translation,
        original: AudioFile,
        translated: AudioFile,
        translatedDirectoryPath: String
    ) {
        self.translation = translation
        self.original = original
        self.translated = translated
        self.translatedDirectoryPath = translatedDirectoryPath
    }
}
