//
//  OutboxEntry.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

struct OutboxEntry: Codable, Equatable, Identifiable {
    // MARK: - Types

    enum Payload: Codable, Equatable {
        case audio(inputFileName: String)
        case media(fileName: String, fileExtension: MediaFileExtension)
        case text(String)
    }

    enum State: String, Codable {
        case failed
        case sending
    }

    // MARK: - Properties

    static let autoRetryCap = 3

    let conversationIDKey: String
    let createdDate: Date
    let fromAccountID: String
    let id: String
    let isPenPalsConversation: Bool
    let payload: Payload
    let recipientUserIDs: [String]

    var attemptCount: Int
    var lastAttemptDate: Date?
    var reservedRemoteID: String?
    var state: State
}
