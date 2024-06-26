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
import CoreArchitecture
import Translator

public struct Message: Codable, EncodedHashable, Equatable {
    // MARK: - Properties

    // Array
    /// In practice, will never contain more than one value due to specification made during decoding.
    public let audioComponents: [AudioMessageReference]?
    public let translations: [Translation]?

    // Bool
    public let hasAudioComponent: Bool
    public let hasImageComponent: Bool

    // Date
    public let readDate: Date?
    public let sentDate: Date

    // String
    public let fromAccountID: String
    public let id: String

    // Other
    public let image: ImageFile?

    // MARK: - Computed Properties

    public var audioComponent: AudioMessageReference? { audioComponents?.first }
    public var hashFactors: [String] {
        @Dependency(\.standardDateFormatter) var dateFormatter: DateFormatter
        var factors = [
            id,
            fromAccountID,
            hasAudioComponent.description,
            hasImageComponent.description,
            dateFormatter.string(from: sentDate),
        ]

        if let readDate {
            factors.append(dateFormatter.string(from: readDate))
        }

        return factors
    }

    public var localAudioFilePath: LocalAudioFilePath? { .init(self) }
    public var localImageFilePath: LocalImageFilePath? { .init(self) }
    /// The translation for this message in the current user's language code.
    public var translation: Translation { translations?.first ?? .empty } // TODO: Make this optional & remove Translation.empty.

    // MARK: - Init

    public init(
        _ id: String,
        fromAccountID: String,
        hasAudioComponent: Bool,
        hasImageComponent: Bool,
        audioComponents: [AudioMessageReference]?,
        image: ImageFile?,
        translations: [Translation]?,
        readDate: Date?,
        sentDate: Date
    ) {
        self.id = id
        self.fromAccountID = fromAccountID
        self.hasAudioComponent = hasAudioComponent
        self.hasImageComponent = hasImageComponent
        self.audioComponents = audioComponents
        self.image = image
        self.translations = translations
        self.readDate = readDate
        self.sentDate = sentDate
    }
}
