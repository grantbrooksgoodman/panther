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

struct AudioMessageReference: Codable, Equatable {
    // MARK: - Properties

    // AudioFile
    let original: AudioFile
    let translated: AudioFile

    // String
    let translatedDirectoryPath: String

    // Translation
    let translation: Translation

    // MARK: - Init

    init(
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
