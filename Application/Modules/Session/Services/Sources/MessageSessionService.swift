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

    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Send Text Message

    public func sendTextMessage(
        _ text: String,
        toUsers users: [User],
        inConversation conversation: Conversation?
    ) async -> Callback<Conversation, Exception> {
        guard let currentUser = clientSession.user.currentUser else {
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

        return await createMessageAndAddToConversation(
            conversation: conversation,
            initiatingUser: currentUser,
            otherUsers: users,
            translations: translations,
            audioComponents: nil
        )
    }

    // MARK: - Send Audio Message

    public func sendAudioMessage(
        _ inputFile: AudioFile,
        toUsers users: [User],
        inConversation conversation: Conversation?
    ) async -> Callback<Conversation, Exception> {
        guard let currentUser = clientSession.user.currentUser else {
            return .failure(.init(
                "Current user has not been set.",
                metadata: [self, #file, #function, #line]
            ))
        }

        let transcribeResult = await services.audio.transcription.transcribeAudioFile(
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

                    let readToFileResult = await services.audio.textToSpeech.readToFile(
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

            return await createMessageAndAddToConversation(
                conversation: conversation,
                initiatingUser: currentUser,
                otherUsers: users,
                translations: translations,
                audioComponents: audioComponents
            )

        case let .failure(exception):
            return .failure(exception)
        }
    }

    // MARK: - Auxiliary

    private func createMessageAndAddToConversation(
        conversation: Conversation?,
        initiatingUser: User,
        otherUsers: [User],
        translations: [Translation],
        audioComponents: [AudioMessageReference]?
    ) async -> Callback<Conversation, Exception> {
        func addMessage(_ message: Message, to conversation: Conversation) async -> Callback<Conversation, Exception> {
            let addMessagesResult = await clientSession.conversation.addMessages([message], to: conversation)

            clientSession.user.startObservingCurrentUserChanges()

            switch addMessagesResult {
            case let .success(conversation):
                return .success(conversation)

            case let .failure(exception):
                return .failure(exception)
            }
        }

        clientSession.user.stopObservingCurrentUserChanges()

        let createMessageResult = await networking.services.message.createMessage(
            fromAccountID: initiatingUser.id,
            translations: translations,
            audioComponents: audioComponents
        )

        switch createMessageResult {
        case let .success(message):
            if let exception = await services.notification.notify(otherUsers, of: message) {
                clientSession.user.startObservingCurrentUserChanges()
                return .failure(exception)
            }

            if let conversation {
                let newParticipants = conversation.participants.map { Participant(userID: $0.userID, hasDeletedConversation: false, isTyping: $0.isTyping) }

                guard newParticipants.map(\.hasDeletedConversation) != conversation.participants.map(\.hasDeletedConversation) else {
                    return await addMessage(message, to: conversation)
                }

                let updateValueResult = await conversation.updateValue(newParticipants, forKey: .participants)

                switch updateValueResult {
                case let .success(conversation):
                    return await addMessage(message, to: conversation)

                case let .failure(exception):
                    clientSession.user.startObservingCurrentUserChanges()
                    return .failure(exception)
                }
            } else {
                var participantUsers = [initiatingUser]
                participantUsers.append(contentsOf: otherUsers)

                let createConversationResult = await networking.services.conversation.createConversation(
                    firstMessage: message,
                    participants: participantUsers.map { Participant(userID: $0.id) }
                )

                clientSession.user.startObservingCurrentUserChanges()

                switch createConversationResult {
                case let .success(conversation):
                    return .success(conversation)

                case let .failure(exception):
                    return .failure(exception)
                }
            }

        case let .failure(exception):
            clientSession.user.startObservingCurrentUserChanges()
            return .failure(exception)
        }
    }
}
