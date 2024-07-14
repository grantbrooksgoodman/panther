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

    // Date
    public let readDate: Date?
    public let sentDate: Date

    // String
    public let fromAccountID: String
    public let id: String

    // Other
    public let contentType: ContentType
    public let media: Media?
    public let translations: [Translation]?

    // MARK: - Computed Properties

    public var audioComponent: AudioMessageReference? { audioComponents?.first }
    public var audioComponents: [AudioMessageReference]? { media?.audioComponents }
    public var hashFactors: [String] {
        @Dependency(\.standardDateFormatter) var dateFormatter: DateFormatter
        var factors = [
            id,
            fromAccountID,
            contentType.rawValue,
            dateFormatter.string(from: sentDate),
        ]

        if let readDate {
            factors.append(dateFormatter.string(from: readDate))
        }

        return factors
    }

    public var imageComponent: ImageFile? { media?.imageComponent }
    public var localAudioFilePath: LocalAudioFilePath? { .init(self) }
    public var localImageFilePath: LocalImageFilePath? { .init(self) }
    /// The translation for this message in the current user's language code.
    public var translation: Translation { translations?.first ?? .empty } // TODO: Make this optional & remove Translation.empty.
    public var videoComponent: URL? { media?.videoComponent }

    // MARK: - Init

    public init(
        _ id: String,
        fromAccountID: String,
        contentType: ContentType,
        media: Media?,
        translations: [Translation]?,
        readDate: Date?,
        sentDate: Date
    ) {
        self.id = id
        self.fromAccountID = fromAccountID
        self.contentType = contentType
        self.media = media
        self.translations = translations
        self.readDate = readDate
        self.sentDate = sentDate
    }
}
