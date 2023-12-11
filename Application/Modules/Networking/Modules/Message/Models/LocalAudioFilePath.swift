//
//  LocalAudioFilePath.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct LocalAudioFilePath: Codable, Equatable {
    // MARK: - Properties

    // String
    public let directoryPathString: String
    public let inputPathString: String
    public let outputPathString: String

    // URL
    public let inputPathURL: URL
    public let outputPathURL: URL

    // MARK: - Init

    public init(
        directoryPathString: String,
        inputPathString: String,
        inputPathURL: URL,
        outputPathString: String,
        outputPathURL: URL
    ) {
        self.directoryPathString = directoryPathString
        self.inputPathString = inputPathString
        self.inputPathURL = inputPathURL
        self.outputPathString = outputPathString
        self.outputPathURL = outputPathURL
    }
}
