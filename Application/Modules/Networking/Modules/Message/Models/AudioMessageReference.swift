//
//  AudioMessageReference.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */

public struct AudioMessageReference: Codable, Equatable {
    // MARK: - Properties

    // AudioFile
    public let original: AudioFile
    public let translated: AudioFile

    // String
    public let directoryPath: String

    // MARK: - Init

    public init(
        _ directoryPath: String,
        original: AudioFile,
        translated: AudioFile
    ) {
        self.directoryPath = directoryPath
        self.original = original
        self.translated = translated
    }
}
