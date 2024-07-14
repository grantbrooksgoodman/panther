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
    public let richContent: RichMessageContent?
    public let translations: [Translation]?

    // MARK: - Computed Properties

    // Array
    public var audioComponents: [AudioMessageReference]? { richContent?.audioComponents }
    public var hashFactors: [String] { getHashFactors() }

    // MediaFile
    public var imageComponent: MediaFile? { richContent?.imageComponent }
    public var videoComponent: MediaFile? { richContent?.videoComponent }

    // Other
    public var audioComponent: AudioMessageReference? { audioComponents?.first }
    public var localAudioFilePath: LocalAudioFilePath? { .init(self) }
    public var localMediaFilePath: LocalMediaFilePath? { .init(self) }
    /// The translation for this message in the current user's language code.
    public var translation: Translation { translations?.first ?? .empty } // TODO: Make this optional & remove Translation.empty.

    // MARK: - Init

    public init(
        _ id: String,
        fromAccountID: String,
        contentType: ContentType,
        richContent: RichMessageContent?,
        translations: [Translation]?,
        readDate: Date?,
        sentDate: Date
    ) {
        self.id = id
        self.fromAccountID = fromAccountID
        self.contentType = contentType
        self.richContent = richContent
        self.translations = translations
        self.readDate = readDate
        self.sentDate = sentDate
    }

    // MARK: - Computed Property Getters

    private func getHashFactors() -> [String] {
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
}
