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

    // Array
    /// In practice, will never contain more than one value due to specification made during decoding.
    public let audioComponents: [AudioMessageReference]?
    public let translations: [Translation]

    // Bool
    public let hasAudioComponent: Bool

    // Date
    public let readDate: Date?
    public let sentDate: Date

    // String
    public let fromAccountID: String
    public let id: String

    // MARK: - Computed Properties

    public var audioComponent: AudioMessageReference? { audioComponents?.first }
    public var hashFactors: [String] {
        @Dependency(\.standardDateFormatter) var dateFormatter: DateFormatter
        var factors = [
            id,
            fromAccountID,
            hasAudioComponent.description,
            dateFormatter.string(from: sentDate),
        ]

        if let readDate {
            factors.append(dateFormatter.string(from: readDate))
        }

        return factors
    }

    public var localAudioFilePath: LocalAudioFilePath? { .init(self) }
    /// The translation for this message in the current user's language code.
    public var translation: Translation { translations.first! }

    // MARK: - Init

    public init(
        _ id: String,
        fromAccountID: String,
        hasAudioComponent: Bool,
        audioComponents: [AudioMessageReference]?,
        translations: [Translation],
        readDate: Date?,
        sentDate: Date
    ) {
        assert(!translations.isEmpty, "Initialized Message with empty Translation array")
        self.id = id
        self.fromAccountID = fromAccountID
        self.hasAudioComponent = hasAudioComponent
        self.audioComponents = audioComponents
        self.translations = translations
        self.readDate = readDate
        self.sentDate = sentDate
    }
}
