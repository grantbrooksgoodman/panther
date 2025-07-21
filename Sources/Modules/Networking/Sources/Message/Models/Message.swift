//
//  Message.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking
import Translator

public struct Message: Codable, EncodedHashable, Equatable {
    // MARK: - Properties

    // Array
    public let readReceipts: [ReadReceipt]?
    public let translationReferences: [TranslationReference]?
    public let translations: [Translation]?

    // String
    public let fromAccountID: String
    public let id: String

    // Other
    public static let empty: Message = .init(
        "",
        fromAccountID: "",
        contentType: .text,
        richContent: nil,
        translationReferences: nil,
        translations: nil,
        readReceipts: nil,
        sentDate: .init(timeIntervalSince1970: 0)
    )

    public let contentType: HostedContentType
    public let richContent: RichMessageContent?
    public let sentDate: Date

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
    public var currentUserReadReceipt: ReadReceipt? { getCurrentUserReadReceipt() }
    public var localAudioFilePath: LocalAudioFilePath? { .init(self) }
    public var localMediaFilePath: LocalMediaFilePath? { .init(self) }
    /// - Note: Will always return `nil` if the message is not in the currently presented conversation.
    public var reactions: [Reaction]? { getReactions() }
    /// The translation for this message in the current user's language code.
    public var translation: Translation? { translations?.first }

    // MARK: - Init

    public init(
        _ id: String,
        fromAccountID: String,
        contentType: HostedContentType,
        richContent: RichMessageContent?,
        translationReferences: [TranslationReference]?,
        translations: [Translation]?,
        readReceipts: [ReadReceipt]?,
        sentDate: Date
    ) {
        self.id = id
        self.fromAccountID = fromAccountID
        self.contentType = contentType
        self.richContent = richContent
        self.translationReferences = translationReferences
        self.translations = translations
        self.readReceipts = readReceipts
        self.sentDate = sentDate
    }

    // MARK: - Computed Property Getters

    private func getCurrentUserReadReceipt() -> ReadReceipt? {
        readReceipts?.first(where: { $0.userID == User.currentUserID })
    }

    private func getHashFactors() -> [String] {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        var factors = [
            id,
            fromAccountID,
            contentType.rawValue,
            dateFormatter.string(from: sentDate),
        ]

        if let readReceipts {
            factors.append(contentsOf: readReceipts.map(\.encoded))
        }

        return factors.sorted()
    }

    private func getReactions() -> [Reaction]? {
        @Dependency(\.clientSession.conversation.fullConversation) var conversation: Conversation?
        guard let messages = conversation?.messages,
              messages.contains(self),
              let reactionMetadata = conversation?.reactionMetadata,
              let reactions = reactionMetadata.first(where: { $0.messageID == id })?.reactions else { return nil }
        return reactions
    }
}
