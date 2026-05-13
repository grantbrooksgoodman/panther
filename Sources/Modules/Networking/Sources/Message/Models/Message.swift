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

@RemotelyUpdatable
struct Message: Codable, EncodedHashable, Hashable {
    // MARK: - Properties

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

    let contentType: HostedContentType
    let fromAccountID: String
    let id: String
    @Updatable(nilIf: .isEmpty) let readReceipts: [ReadReceipt]?
    let richContent: RichMessageContent?
    let sentDate: Date
    let translationReferences: [TranslationReference]?
    let translations: [Translation]?

    // MARK: - Computed Properties

    var audioComponent: AudioMessageReference? { audioComponents?.first }
    var audioComponents: [AudioMessageReference]? { richContent?.audioComponents }
    var currentUserReadReceipt: ReadReceipt? { getCurrentUserReadReceipt() }
    var documentComponent: MediaFile? { richContent?.documentComponent }
    var hashFactors: [String] { getHashFactors() }
    var imageComponent: MediaFile? { richContent?.imageComponent }
    var localAudioFilePath: LocalAudioFilePath? { .init(self) }
    var localMediaFilePath: LocalMediaFilePath? { .init(self) }
    /// - Note: Will always return `nil` if the message is not in the currently presented conversation.
    var reactions: [Reaction]? { getReactions() }
    /// The translation for this message in the current user's language code.
    var translation: Translation? { translations?.first }
    var videoComponent: MediaFile? { richContent?.videoComponent }

    // MARK: - Init

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

        if let readReceipts {
            factors.append(contentsOf: readReceipts.map(\.encoded))
        }

        return factors.sorted()
    }

    private func getReactions() -> [Reaction]? {
        @Dependency(\.clientSession.conversation.fullConversation) var conversation: Conversation?
        guard let reactionMetadata = conversation?.reactionMetadata,
              let reactions = reactionMetadata.first(where: { $0.messageID == id })?.reactions else { return nil }
        return reactions
    }
}
