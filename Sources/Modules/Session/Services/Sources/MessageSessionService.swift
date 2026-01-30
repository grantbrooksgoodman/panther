//
//  MessageSessionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking
import Translator

struct MessageSessionService {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.MessageSessionService
    private typealias Strings = AppConstants.Strings.MessageSessionService

    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.languageRecognitionService) private var languageRecognitionService: LanguageRecognitionService
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Send Audio Message

    // swiftlint:disable:next function_body_length
    func sendAudioMessage(
        _ inputFile: AudioFile,
        toUsers users: [User],
        inConversation conversation: (value: Conversation?, isPenPalsConversation: Bool)
    ) async -> Callback<Conversation, Exception> {
        guard let currentUser = clientSession.user.currentUser else {
            return .failure(.init(
                "Current user has not been set.",
                metadata: .init(sender: self)
            ))
        }

        var transcription: String!
        let transcribeResult = await services.audio.transcription.transcribeAudioFile(
            at: inputFile.url,
            languageCode: currentUser.languageCode
        )

        switch transcribeResult { // swiftlint:disable:next identifier_name
        case let .success(_transcription): transcription = _transcription
        case let .failure(exception): return .failure(exception)
        }

        NotificationCenter.default.post(
            name: .init(Strings.audioMessageTranscriptionSucceededNotificationName),
            object: self,
            userInfo: [
                Strings.conversationIDKeyNotificationUserInfoKey: conversation.value?.id.key ?? CommonConstants.newConversationID,
                Strings.inputFileNotificationUserInfoKey: inputFile,
                Strings.isPenPalsConversationNotificationUserInfoKey: conversation.isPenPalsConversation,
            ]
        )

        if shouldAnimateDeliveryProgress(in: conversation.value) {
            clientSession.deliveryProgressIndicator?.startAnimatingDeliveryProgress()
        }

        let users = users.filter { $0 != currentUser }
        var translations = [Translation]()
        var audioComponents = [AudioMessageReference]()

        for languageCode in users.map(\.languageCode).unique {
            let translateResult = await networking.hostedTranslation.translate(
                .init(transcription),
                with: .init(from: currentUser.languageCode, to: languageCode),
                enhance: getEnhancementConfiguration(
                    for: conversation.value,
                    isAudioMessage: true,
                    userCount: users.count
                )
            )

            incrementDeliveryProgress(
                in: conversation.value,
                by: Floats.translationDeliveryProgressIncrement / .init(users.count)
            )

            var translation: Translation!
            switch translateResult { // swiftlint:disable:next identifier_name
            case let .success(_translation):
                translation = _translation
                translations.append(_translation)

            case let .failure(exception):
                return .failure(exception)
            }

            if await networking.messageService.audio.preRecordedOutputExists(for: translation) {
                incrementDeliveryProgress(
                    in: conversation.value,
                    by: Floats.readToFileDeliveryProgressIncrement / .init(users.count)
                )

                audioComponents.append(.init(
                    translation: translation,
                    original: inputFile,
                    translated: inputFile,
                    translatedDirectoryPath: "\(NetworkPath.audioTranslations.rawValue)/\(translation.reference.hostingKey)"
                ))
            } else {
                let readToFileResult = await services.audio.textToSpeech.readToFile(
                    text: translation.output.sanitized,
                    languageCode: languageCode
                )

                incrementDeliveryProgress(
                    in: conversation.value,
                    by: Floats.readToFileDeliveryProgressIncrement / .init(users.count)
                )

                switch readToFileResult {
                case let .success(url):
                    guard let outputFile = AudioFile(url) else {
                        return .failure(.init(
                            "Failed to generate output audio file.",
                            metadata: .init(sender: self)
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
            }
        }

        guard translations.isWellFormed else {
            return .failure(.init(
                "Translations fail validation.",
                metadata: .init(sender: self)
            ))
        }

        return await createMessageAndAddToConversation(
            conversation: conversation,
            initiatingUser: currentUser,
            otherUsers: users,
            richContent: .audio(audioComponents),
            translations: translations
        )
    }

    // MARK: - Send Media Message

    func sendMediaMessage(
        _ mediaFile: MediaFile,
        toUsers users: [User],
        inConversation conversation: (value: Conversation?, isPenPalsConversation: Bool)
    ) async -> Callback<Conversation, Exception> {
        guard let currentUser = clientSession.user.currentUser else {
            return .failure(.init(
                "Current user has not been set.",
                metadata: .init(sender: self)
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

    func sendTextMessage(
        _ text: String,
        toUsers users: [User],
        inConversation conversation: (value: Conversation?, isPenPalsConversation: Bool)
    ) async -> Callback<Conversation, Exception> {
        guard let currentUser = clientSession.user.currentUser else {
            return .failure(.init(
                "Current user has not been set.",
                metadata: .init(sender: self)
            ))
        }

        let users = users.filter { $0 != currentUser }
        var translations = [Translation]()

        var text = text
        if build.isDeveloperModeEnabled,
           await languageRecognitionService.matchConfidence(
               for: text,
               inLanguage: currentUser.languageCode
           ) < Floats.languageRecognitionServiceMatchConfidenceThreshold {
            let translateResult = await networking.hostedTranslation.translate(
                .init(text),
                with: .init(from: "en", to: currentUser.languageCode),
                enhance: getEnhancementConfiguration(
                    for: conversation.value,
                    isAudioMessage: false,
                    userCount: users.count
                )
            )

            switch translateResult {
            case let .success(translation): text = translation.output.sanitized
            case let .failure(exception): Logger.log(exception)
            }
        }

        for languageCode in users.map(\.languageCode).unique {
            let translateResult = await networking.hostedTranslation.translate(
                .init(text),
                with: .init(from: currentUser.languageCode, to: languageCode),
                enhance: getEnhancementConfiguration(
                    for: conversation.value,
                    isAudioMessage: false,
                    userCount: users.count
                )
            )

            incrementDeliveryProgress(
                in: conversation.value,
                by: Floats.translationDeliveryProgressIncrement
            )

            switch translateResult {
            case let .success(translation): translations.append(translation)
            case let .failure(exception): return .failure(exception)
            }
        }

        guard translations.isWellFormed else {
            return .failure(.init(
                "Translations fail validation.",
                metadata: .init(sender: self)
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

    // swiftlint:disable:next function_body_length
    private func createMessageAndAddToConversation(
        conversation: (value: Conversation?, isPenPalsConversation: Bool),
        initiatingUser: User,
        otherUsers: [User],
        richContent: RichMessageContent?,
        translations: [Translation]?
    ) async -> Callback<Conversation, Exception> {
        func addMessage(_ message: Message, to conversation: Conversation) async -> Callback<Conversation, Exception> {
            let addMessagesResult = await clientSession.conversation.addMessages(
                [message],
                to: conversation
            )

            incrementDeliveryProgress(
                in: conversation,
                by: Floats.addMessageDeliveryProgressIncrement
            )

            clientSession.user.startObservingCurrentUserChanges()
            switch addMessagesResult {
            case let .success(conversation): return .success(conversation)
            case let .failure(exception): return .failure(exception)
            }
        }

        func notifyUsers(
            of message: Message,
            conversationIDKey: String,
            isPenPalsConversation: Bool
        ) {
            Task.background {
                if let exception = await services.notification.notify(
                    otherUsers.filter { !($0.blockedUserIDs ?? []).contains(initiatingUser.id) },
                    message: message,
                    conversationIDKey: conversationIDKey,
                    isPenPalsConversation: isPenPalsConversation
                ) {
                    Logger.log(exception, domain: .notifications)
                }

                incrementDeliveryProgress(
                    in: conversation.value,
                    by: Floats.notifyDeliveryProgressIncrement
                )
            }
        }

        clientSession.user.stopObservingCurrentUserChanges()

        let createMessageResult = await networking.messageService.createMessage(
            fromAccountID: initiatingUser.id,
            richContent: richContent,
            translations: translations
        )

        incrementDeliveryProgress(
            in: conversation.value,
            by: Floats.createMessageDeliveryProgressIncrement
        )

        switch createMessageResult {
        case let .success(message):
            if let conversation = conversation.value {
                notifyUsers(
                    of: message,
                    conversationIDKey: conversation.id.key,
                    isPenPalsConversation: conversation.metadata.isPenPalsConversation
                )

                let newParticipants = conversation.participants.map { Participant(userID: $0.userID, hasDeletedConversation: false, isTyping: $0.isTyping) }
                guard newParticipants.map(\.hasDeletedConversation) != conversation.participants.map(\.hasDeletedConversation) else {
                    return await addMessage(message, to: conversation)
                }

                let updateValueResult = await conversation.updateValue(
                    newParticipants,
                    forKey: .participants
                )

                incrementDeliveryProgress(
                    in: conversation,
                    by: Floats.updateValueDeliveryProgressIncrement
                )

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
                    isPenPalsConversation: conversation.isPenPalsConversation,
                    participants: participantUsers.map { Participant(userID: $0.id) }
                )

                services.analytics.logEvent(.createNewConversation)
                incrementDeliveryProgress(
                    in: conversation.value,
                    by: Floats.createConversationDeliveryProgressIncrement
                )
                clientSession.user.startObservingCurrentUserChanges()

                switch createConversationResult {
                case let .success(conversation):
                    notifyUsers(
                        of: message,
                        conversationIDKey: conversation.id.key,
                        isPenPalsConversation: conversation.metadata.isPenPalsConversation
                    )

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

    private func getEnhancementConfiguration(
        for conversation: Conversation?,
        isAudioMessage: Bool,
        userCount: Int,
    ) -> EnhancementConfiguration? { // swiftlint:disable:next line_length
        let audioMessageContext = "This is the transcription of an audio message. If you spot any red flags grammatically or coherence-wise, please correct them."

        guard clientSession.user.currentUser?.aiEnhancedTranslationsEnabled == true,
              userCount == 1,
              let messageReadout = conversation?.messageReadout else {
            return isAudioMessage ? .init(additionalContext: audioMessageContext) : nil
        }

        let additionalContext = isAudioMessage ? audioMessageContext : ""
        return .init( // swiftlint:disable line_length
            additionalContext: "\(additionalContext)\n" + """
            Attached is a readout of the most recent messages in this conversation, sorted by latest (descending) send date.
            Ensure the addressee is spoken to with pronouns consistent in gender and number used in previous messages from 'You'.
            If needed, use the participant names to infer the proper gender to use, but ONLY after not having reached a definitive conclusion based on the gender used in previous messages.
            Maintain the same register and tone as used by 'You' throughout the conversation.
            -----
            BEGIN MESSAGE READOUT:
            \(messageReadout)
            """
        ) // swiftlint:enable line_length
    }

    private func incrementDeliveryProgress(in conversation: Conversation?, by: Float) {
        guard shouldAnimateDeliveryProgress(in: conversation) else { return }
        clientSession.deliveryProgressIndicator?.incrementDeliveryProgress(by: by)
    }

    private func shouldAnimateDeliveryProgress(in conversation: Conversation?) -> Bool {
        clientSession.conversation.currentConversation?.id.key == conversation?.id.key
    }
}

private extension Conversation {
    var messageReadout: String? {
        guard let messages else { return nil }

        var messageStrings = [String]()
        for message in messages
            .sortedByDescendingSentDate
            .filter({ $0.contentType == .text }) {
            guard let matchingUser = UserCache
                .knownUsers
                .first(where: { $0.id == message.fromAccountID }) else { continue }

            var messageText = message.translation?.output.sanitized
            var userDisplayName = matchingUser.displayName

            if message.fromAccountID == User.currentUserID {
                messageText = message.translation?.input.value
                userDisplayName = "You"
            }

            if userDisplayName == matchingUser.phoneNumber.formattedString() {
                userDisplayName = "Anonymous User"
            }

            guard let messageText else { continue }
            messageStrings.append("\(userDisplayName): '\(messageText)'")
        }

        messageStrings.removeFirst()
        return messageStrings.joined(separator: "\n")
    }
}

// swiftlint:enable file_length type_body_length
