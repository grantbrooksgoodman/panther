//
//  MessageSessionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux
import Translator

public struct MessageSessionService {
    // MARK: - Dependencies

    @Dependency(\.commonServices.audio) private var audioService: AudioService
    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.clientSessionService) private var clientSessionService: ClientSessionService

    // MARK: - Send Text Message

    public func sendTextMessage(
        _ text: String,
        toUsers users: [User],
        inConversation conversation: Conversation?
    ) async -> Callback<Conversation, Exception> {
        guard let currentUser = clientSessionService.user.currentUser else {
            return .failure(.init(
                "Current user has not been set.",
                metadata: [self, #file, #function, #line]
            ))
        }

        let users = users.filter { $0 != currentUser }

        var translations = [Translation]()

        for languageCode in users.map(\.languageCode) {
            let translateResult = await networking.services.translation.translate(
                .init(text),
                with: .init(from: currentUser.languageCode, to: languageCode)
            )

            switch translateResult {
            case let .success(translation):
                translations.append(translation)

            case let .failure(exception):
                return .failure(exception)
            }
        }

        guard translations.isWellFormed else {
            return .failure(.init(
                "Translations fail validation.",
                metadata: [self, #file, #function, #line]
            ))
        }

        let createMessageResult = await networking.services.message.createMessage(
            fromAccountID: currentUser.id.key,
            translations: translations,
            audioComponents: nil
        )

        switch createMessageResult {
        case let .success(message):
            if let conversation {
                return await clientSessionService.conversation.addMessages(
                    [message],
                    to: conversation
                )
            } else {
                var participantUsers = [currentUser]
                participantUsers.append(contentsOf: users)
                return await networking.services.conversation.createConversation(
                    firstMessage: message,
                    participants: participantUsers.map { Participant(userIDKey: $0.id.key) }
                )
            }

        case let .failure(exception):
            return .failure(exception)
        }
    }

    // MARK: - Send Audio Message

    public func sendAudioMessage(
        _ inputFile: AudioFile,
        toUsers users: [User],
        inConversation conversation: Conversation?
    ) async -> Callback<Conversation, Exception> {
        guard let currentUser = clientSessionService.user.currentUser else {
            return .failure(.init(
                "Current user has not been set.",
                metadata: [self, #file, #function, #line]
            ))
        }

        let transcribeResult = await audioService.transcription.transcribeAudioFile(
            at: inputFile.url,
            languageCode: currentUser.languageCode
        )

        switch transcribeResult {
        case let .success(transcription):
            let users = users.filter { $0 != currentUser }
            var translations = [Translation]()
            var audioComponents = [AudioMessageReference]()

            for languageCode in users.map(\.languageCode) {
                let translateResult = await networking.services.translation.translate(
                    .init(transcription),
                    with: .init(from: currentUser.languageCode, to: languageCode)
                )

                switch translateResult {
                case let .success(translation):
                    translations.append(translation)

                    let readToFileResult = await audioService.textToSpeech.readToFile(
                        text: translation.output,
                        languageCode: languageCode
                    )

                    switch readToFileResult {
                    case let .success(url):
                        guard let outputFile = AudioFile(url) else {
                            return .failure(.init(
                                "Failed to generate output audio file.",
                                metadata: [self, #file, #function, #line]
                            ))
                        }

                        audioComponents.append(.init(
                            translation: translation,
                            original: inputFile,
                            translated: outputFile,
                            translatedDirectoryPath: "\(networking.config.paths.audioTranslations)/\(translation.reference.hostingKey)"
                        ))

                    case let .failure(exception):
                        return .failure(exception)
                    }

                case let .failure(exception):
                    return .failure(exception)
                }
            }

            guard translations.isWellFormed else {
                return .failure(.init(
                    "Translations fail validation.",
                    metadata: [self, #file, #function, #line]
                ))
            }

            let createMessageResult = await networking.services.message.createMessage(
                fromAccountID: currentUser.id.key,
                translations: translations,
                audioComponents: audioComponents
            )

            switch createMessageResult {
            case let .success(message):
                if let conversation {
                    return await clientSessionService.conversation.addMessages(
                        [message],
                        to: conversation
                    )
                } else {
                    var participantUsers = [currentUser]
                    participantUsers.append(contentsOf: users)
                    return await networking.services.conversation.createConversation(
                        firstMessage: message,
                        participants: participantUsers.map { Participant(userIDKey: $0.id.key) }
                    )
                }

            case let .failure(exception):
                return .failure(exception)
            }

        case let .failure(exception):
            return .failure(exception)
        }
    }
}
