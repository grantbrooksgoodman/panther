//
//  User.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public struct User: Codable, CompressedHashable, Equatable {
    // MARK: - Properties

    // Array
    public let conversations: [Conversation]?
    public let pushTokens: [String]?

    // Other
    public let id: UserID
    public let languageCode: String
    public let phoneNumber: PhoneNumber

    // MARK: - Computed Properties

    public var canSendAudioMessages: Bool {
        @Dependency(\.commonServices.audio.transcription) var transcriptionService: TranscriptionService
        return transcriptionService.isTranscriptionSupported(for: languageCode)
    }

    public var hashFactors: [String] {
        var factors = [id.key]

        if let conversations {
            factors.append(contentsOf: conversations.map(\.compressedHash))
        }

        if let pushTokens {
            factors.append(contentsOf: pushTokens)
        }

        factors.append(languageCode)
        factors.append(phoneNumber.compressedHash)
        return factors
    }

    // MARK: - Init

    public init(
        _ id: UserID,
        conversations: [Conversation]?,
        languageCode: String,
        phoneNumber: PhoneNumber,
        pushTokens: [String]?
    ) {
        self.id = id
        self.conversations = conversations
        self.languageCode = languageCode
        self.phoneNumber = phoneNumber
        self.pushTokens = pushTokens
    }

    // MARK: - Methods

    public func canSendAudioMessages(to user: User) -> Bool {
        @Dependency(\.commonServices.audio.textToSpeech) var textToSpeechService: TextToSpeechService
        return canSendAudioMessages && textToSpeechService.isTextToSpeechSupported(for: user.languageCode)
    }
}
