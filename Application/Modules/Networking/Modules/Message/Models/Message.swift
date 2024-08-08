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
    public var documentComponent: MediaFile? { richContent?.documentComponent }
    public var imageComponent: MediaFile? { richContent?.imageComponent }
    public var videoComponent: MediaFile? { richContent?.videoComponent }

    // Other
    public var audioComponent: AudioMessageReference? { audioComponents?.first }
    public var localAudioFilePath: LocalAudioFilePath? { .init(self) }
    public var localMediaFilePath: LocalMediaFilePath? { get async { await .init(self) } }
    /// The translation for this message in the current user's language code.
    public var translation: Translation? { translations?.first }

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

    // MARK: - Resolve Media File Extension

    public func resolveMediaFileExtension(_ messageID: String) async -> Callback<String, Exception> {
        @Dependency(\.networking) var networking: Networking

        let commonParams = ["MessageID": messageID]

        guard contentType == .media else {
            return .failure(.init(
                "Message does not have a media component.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        func satisfiesConstraints(_ string: String) -> Bool {
            let isAudioCAF = string == MediaFileExtension.audio(.caf).rawValue
            let isAudioM4A = string == MediaFileExtension.audio(.m4a).rawValue
            return !isAudioCAF && !isAudioM4A
        }

        let fileExtensions = MediaFileExtension.allCases.map(\.rawValue).filter { satisfiesConstraints($0) }
        for fileExtension in fileExtensions {
            let itemExistsResult = await networking.storage.itemExists(at: "\(networking.config.paths.media)/\(messageID).\(fileExtension)")

            switch itemExistsResult {
            case let .success(itemExists):
                guard itemExists else { continue }
                return .success(fileExtension)

            case let .failure(exception):
                return .failure(exception.appending(extraParams: commonParams))
            }
        }

        return .failure(.init(
            "Media item does not exist.",
            metadata: [self, #file, #function, #line]
        ).appending(extraParams: commonParams))
    }

    // MARK: - Computed Property Getters

    private func getHashFactors() -> [String] {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
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
