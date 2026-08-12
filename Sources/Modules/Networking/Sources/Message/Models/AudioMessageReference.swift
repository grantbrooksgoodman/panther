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

/// A reference to an audio message's original and translated audio.
struct AudioMessageReference: Codable, Equatable {
    // MARK: - Properties

    /// The original audio recorded by the sender.
    let original: AudioFile

    /// The audio translated into the recipient's language.
    let translated: AudioFile

    /// The path to the directory containing the translated audio.
    let translatedDirectoryPath: String

    /// The translation associated with the audio.
    let translation: Translation

    // MARK: - Init

    /// Creates an audio message reference.
    ///
    /// - Parameters:
    ///   - translation: The translation associated with the audio.
    ///   - original: The original audio recorded by the sender.
    ///   - translated: The audio translated into the recipient's language.
    ///   - translatedDirectoryPath: The path to the directory containing the translated audio.
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
