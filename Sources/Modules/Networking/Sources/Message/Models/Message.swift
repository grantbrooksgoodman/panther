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

/// A message in a conversation.
///
/// A message carries its sender, content type, sent date, and – depending on its type – rich
/// audio or media content, translations, and read receipts. Text messages carry translations;
/// audio and media messages carry rich content resolved from remote storage.
@RemotelyUpdatable
struct Message: Codable, EncodedHashable, Hashable {
    // MARK: - Properties

    /// An empty message placeholder.
    static let empty: Message = .init(
        "",
        fromAccountID: "",
        contentType: .text,
        richContent: nil,
        translationReferences: nil,
        translations: nil,
        readReceipts: nil,
        sentDate: .init(timeIntervalSince1970: 0)
    )

    /// The message's content type.
    let contentType: HostedContentType

    /// The identifier of the account that sent the message.
    let fromAccountID: String

    /// The message's unique identifier.
    let id: String

    /// The message's read receipts, or `nil` if it has none.
    @Updatable(nilIf: .isEmpty) let readReceipts: [ReadReceipt]?

    /// The message's rich content – audio or media – if any.
    let richContent: RichMessageContent?

    /// The date the message was sent.
    let sentDate: Date

    /// The references to the message's translations.
    let translationReferences: [TranslationReference]?

    /// The message's resolved translations.
    let translations: [Translation]?

    // MARK: - Computed Properties

    /// The message's first audio component, or `nil` if it has none.
    var audioComponent: AudioMessageReference? {
        audioComponents?.first
    }

    /// The message's audio components, or `nil` if it has none.
    var audioComponents: [AudioMessageReference]? {
        richContent?.audioComponents
    }

    /// The current user's read receipt for the message, or `nil` if the user has not read it.
    var currentUserReadReceipt: ReadReceipt? {
        getCurrentUserReadReceipt()
    }

    /// The message's document, or `nil` if its content is not a document.
    var documentComponent: MediaFile? {
        richContent?.documentComponent
    }

    /// The strings that collectively define this instance's identity for hashing purposes, sorted
    /// alphabetically.
    var hashFactors: [String] {
        getHashFactors()
    }

    /// The message's image, or `nil` if its content is not an image.
    var imageComponent: MediaFile? {
        richContent?.imageComponent
    }

    /// The local file path for the message's audio, or `nil` if it is not an audio message.
    var localAudioFilePath: LocalAudioFilePath? {
        .init(self)
    }

    /// The local file path for the message's media, or `nil` if it is not a media message.
    var localMediaFilePath: LocalMediaFilePath? {
        .init(self)
    }

    /// The reactions on the message, or `nil` if it has none.
    ///
    /// - Note: Always returns `nil` if the message is not in the currently presented
    ///   conversation.
    var reactions: [Reaction]? {
        getReactions()
    }

    /// The translation for this message in the current user's language code.
    var translation: Translation? {
        translations?.first
    }

    /// The message's video, or `nil` if its content is not a video.
    var videoComponent: MediaFile? {
        richContent?.videoComponent
    }

    // MARK: - Init

    /// Creates a message with the given properties.
    ///
    /// - Parameters:
    ///   - id: The message's unique identifier.
    ///   - fromAccountID: The identifier of the account that sent the message.
    ///   - contentType: The message's content type.
    ///   - richContent: The message's rich content, or `nil` if it has none.
    ///   - translationReferences: The references to the message's translations, or `nil` if it
    ///     has none.
    ///   - translations: The message's resolved translations, or `nil` if it has none.
    ///   - readReceipts: The message's read receipts, or `nil` if it has none.
    ///   - sentDate: The date the message was sent.
    init(
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

    // MARK: - Hashable Conformance

    /// Hashes the message's ``hashFactors``.
    func hash(into hasher: inout Hasher) {
        hasher.combine(hashFactors)
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

        // Render read receipt dates with the UTC hash
        // formatter rather than the wire-format encoded
        // property, which uses the ambient timezone.
        if let readReceipts {
            factors.append(contentsOf: readReceipts.map {
                "\($0.userID) | \(dateFormatter.string(from: $0.readDate))"
            })
        }

        return factors.sorted()
    }

    private func getReactions() -> [Reaction]? {
        @Dependency(\.clientSession.entity.conversation.currentConversation) var conversation: Conversation?
        guard let reactionMetadata = conversation?.reactionMetadata,
              let reactions = reactionMetadata.first(where: {
                  $0.messageID == id
              })?.reactions else { return nil }
        return reactions
    }
}
