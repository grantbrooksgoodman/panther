//
//  OutboxEntry.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A message queued in the outbox for delivery.
struct OutboxEntry: Codable {
    // MARK: - Types

    /// The content of an outbox entry.
    enum Payload: Codable {
        /// An audio message, carrying the file name of its recorded input.
        case audio(inputFileName: String)

        /// A media message, carrying its file name and extension.
        case media(fileName: String, fileExtension: MediaFileExtension)

        /// A text message, carrying its text.
        case text(String)
    }

    /// The delivery state of an outbox entry.
    enum State: String, Codable {
        /// The entry's last delivery attempt failed.
        case failed

        /// The entry is currently being delivered.
        case sending
    }

    // MARK: - Properties

    /// The maximum number of times an entry is automatically retried.
    static let autoRetryCap = 3

    /// The identifier key of the conversation the entry belongs to.
    let conversationIDKey: String

    /// The date the entry was created.
    let createdDate: Date

    /// The identifier of the account that sent the entry.
    let fromAccountID: String

    /// The entry's unique identifier.
    let id: String

    /// A Boolean value that indicates whether the entry belongs to a PenPals conversation.
    let isPenPalsConversation: Bool

    /// The entry's content.
    let payload: Payload

    /// The identifiers of the users the entry is addressed to.
    let recipientUserIDs: [String]

    /// The number of delivery attempts made for the entry.
    var attemptCount: Int

    /// The date of the entry's last delivery attempt, or `nil` if none has been made.
    var lastAttemptDate: Date?

    /// The remote identifier reserved for the entry's message, or `nil` if none has been reserved.
    var reservedRemoteID: String?

    /// The entry's delivery state.
    var state: State

    /// The transcription of the entry's audio, or `nil` if it has none.
    var transcription: String?
}
