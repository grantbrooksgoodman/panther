//
//  MessageSessionService.swift
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

public struct MessageSessionService {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.MessageSessionService
    private typealias Strings = AppConstants.Strings.MessageSessionService

    // MARK: - Dependencies

    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices) private var services: CommonServices

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
            NotificationCenter.default.post(
                name: .init(Strings.audioMessageTranscriptionSucceededNotificationName),
                object: self,
                userInfo: [
                    Strings.conversationIDKeyNotificationUserInfoKey: conversation?.id.key ?? CommonConstants.newConversationID,
                    Strings.inputFileNotificationUserInfoKey: inputFile,
                ]
            )

            if shouldAnimateDeliveryProgress(in: conversation) {
                clientSession.deliveryProgressIndicator?.startAnimatingDeliveryProgress()
            }

            let users = users.filter { $0 != currentUser }
            var translations = [Translation]()
            var audioComponents = [AudioMessageReference]()

            for languageCode in users.map(\.languageCode).unique {
                let translateResult = await networking.translationService.translate(
                    .init(transcription),
                    with: .init(from: currentUser.languageCode, to: languageCode)
                )

                incrementDeliveryProgress(in: conversation, by: Floats.translationDeliveryProgressIncrement / .init(users.count))

                switch translateResult {
                case let .success(translation):
                    translations.append(translation)

                    let readToFileResult = await services.audio.textToSpeech.readToFile(
                        text: translation.output,
                        languageCode: languageCode
                    )

                    incrementDeliveryProgress(in: conversation, by: Floats.readToFileDeliveryProgressIncrement / .init(users.count))

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
                            translatedDirectoryPath: "\(NetworkPath.audioTranslations.rawValue)/\(translation.reference.hostingKey)"
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
                richContent: .audio(audioComponents),
                translations: translations
            )

        case let .failure(exception):
            return .failure(exception)
        }
    }

    // MARK: - Send Media Message

    public func sendMediaMessage(
        _ mediaFile: MediaFile,
        toUsers users: [User],
        inConversation conversation: Conversation?
    ) async -> Callback<Conversation, Exception> {
        guard let currentUser = clientSession.user.currentUser else {
            return .failure(.init(
                "Current user has not been set.",
                metadata: [self, #file, #function, #line]
            ))
        }

        return await createMessageAndAddToConversation(
            conversation: conversation,
            initiatingUser: currentUser,
            otherUsers: users,
            richContent: .media(mediaFile),
            translations: nil
        )
    }

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

        for languageCode in users.map(\.languageCode).unique {
            let translateResult = await networking.translationService.translate(
                .init(text),
                with: .init(from: currentUser.languageCode, to: languageCode)
            )

            incrementDeliveryProgress(in: conversation, by: Floats.translationDeliveryProgressIncrement)

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
            richContent: nil,
            translations: translations
        )
    }

    // MARK: - Auxiliary

    private func createMessageAndAddToConversation(
        conversation: Conversation?,
        initiatingUser: User,
        otherUsers: [User],
        richContent: RichMessageContent?,
        translations: [Translation]?
    ) async -> Callback<Conversation, Exception> {
        func addMessage(_ message: Message, to conversation: Conversation) async -> Callback<Conversation, Exception> {
            let addMessagesResult = await clientSession.conversation.addMessages([message], to: conversation)

            incrementDeliveryProgress(in: conversation, by: Floats.addMessageDeliveryProgressIncrement)
            clientSession.user.startObservingCurrentUserChanges()

            switch addMessagesResult {
            case let .success(conversation):
                return .success(conversation)

            case let .failure(exception):
                return .failure(exception)
            }
        }

        func notifyUsers(of message: Message, conversationIDKey: String) {
            Task.background {
                if let exception = await services.notification.notify(
                    otherUsers.filter { !($0.blockedUserIDs ?? []).contains(initiatingUser.id) },
                    message: message,
                    conversationIDKey: conversationIDKey
                ) {
                    Logger.log(exception, domain: .notifications)
                }

                incrementDeliveryProgress(in: conversation, by: Floats.notifyDeliveryProgressIncrement)
            }
        }

        clientSession.user.stopObservingCurrentUserChanges()

        let createMessageResult = await networking.messageService.createMessage(
            fromAccountID: initiatingUser.id,
            richContent: richContent,
            translations: translations
        )

        incrementDeliveryProgress(in: conversation, by: Floats.createMessageDeliveryProgressIncrement)

        switch createMessageResult {
        case let .success(message):
            if let conversation {
                notifyUsers(of: message, conversationIDKey: conversation.id.key)

                let newParticipants = conversation.participants.map { Participant(userID: $0.userID, hasDeletedConversation: false, isTyping: $0.isTyping) }
                guard newParticipants.map(\.hasDeletedConversation) != conversation.participants.map(\.hasDeletedConversation) else {
                    return await addMessage(message, to: conversation)
                }

                let updateValueResult = await conversation.updateValue(newParticipants, forKey: .participants)

                incrementDeliveryProgress(in: conversation, by: Floats.updateValueDeliveryProgressIncrement)

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

                let createConversationResult = await networking.conversationService.createConversation(
                    firstMessage: message,
                    participants: participantUsers.map { Participant(userID: $0.id) }
                )

                services.analytics.logEvent(.createNewConversation)
                incrementDeliveryProgress(in: conversation, by: Floats.createConversationDeliveryProgressIncrement)
                clientSession.user.startObservingCurrentUserChanges()

                switch createConversationResult {
                case let .success(conversation):
                    notifyUsers(of: message, conversationIDKey: conversation.id.key)
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

    private func incrementDeliveryProgress(in conversation: Conversation?, by: Float) {
        guard shouldAnimateDeliveryProgress(in: conversation) else { return }
        clientSession.deliveryProgressIndicator?.incrementDeliveryProgress(by: by)
    }

    private func shouldAnimateDeliveryProgress(in conversation: Conversation?) -> Bool {
        clientSession.conversation.currentConversation?.id.key == conversation?.id.key
    }
}
