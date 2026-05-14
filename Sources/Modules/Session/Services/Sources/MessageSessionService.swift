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
    @Dependency(\.notificationCenter) private var notificationCenter: NotificationCenter
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

        notificationCenter.post(
            name: .init(Strings.audioMessageTranscriptionSucceededNotificationName),
            object: self,
            userInfo: [
                Strings.conversationIDKeyNotificationUserInfoKey: conversation.value?.id.key ?? CommonConstants.newConversationID,
                Strings.inputFileNotificationUserInfoKey: inputFile,
                Strings.isPenPalsConversationNotificationUserInfoKey: conversation.isPenPalsConversation,
            ]
        )

        if shouldAnimateDeliveryProgress(in: conversation.value) {
            await clientSession.deliveryProgressIndicator?.startAnimatingDeliveryProgress()
        }

        let users = users.filter { $0 != currentUser }
        let uniqueLanguageCodes = users.map(\.languageCode).unique
        let enhancementConfig = await getEnhancementConfiguration(
            for: conversation.value,
            isAudioMessage: true,
            userCount: users.count
        )

        var aggregatedTranslations: [Translation?] = Array(
            repeating: nil,
            count: uniqueLanguageCodes.count
        )

        var aggregatedAudioComponents: [AudioMessageReference?] = Array(
            repeating: nil,
            count: uniqueLanguageCodes.count
        )

        let taskGroupResult: Callback<Void, Exception> = await withTaskGroup(
            of: (Int, Callback<(Translation, AudioMessageReference), Exception>).self
        ) { taskGroup in
            for (index, languageCode) in uniqueLanguageCodes.enumerated() {
                taskGroup.addTask { [self, transcription = transcription as String] in
                    let translateResult = await networking.hostedTranslation.translate(
                        .init(transcription),
                        with: .init(
                            from: currentUser.languageCode,
                            to: languageCode
                        ),
                        enhance: enhancementConfig
                    )

                    switch translateResult {
                    case let .success(translation):
                        if await networking.messageService.audio.preRecordedOutputExists(
                            for: translation
                        ) {
                            let audioComponent = AudioMessageReference(
                                translation: translation,
                                original: inputFile,
                                translated: inputFile,
                                translatedDirectoryPath: "\(NetworkPath.audioTranslations.rawValue)/\(translation.reference.hostingKey)"
                            )

                            return (index, .success((translation, audioComponent)))
                        } else {
                            let readToFileResult = await services.audio.textToSpeech.readToFile(
                                text: translation.output.sanitized,
                                languageCode: languageCode
                            )

                            switch readToFileResult {
                            case let .success(url):
                                guard let outputFile = AudioFile(url) else {
                                    return (index, .failure(.init(
                                        "Failed to generate output audio file.",
                                        metadata: .init(sender: self)
                                    )))
                                }

                                let audioComponent = AudioMessageReference(
                                    translation: translation,
                                    original: inputFile,
                                    translated: outputFile,
                                    translatedDirectoryPath: "\(NetworkPath.audioTranslations.rawValue)/\(translation.reference.hostingKey)"
                                )

                                return (index, .success((translation, audioComponent)))

                            case let .failure(exception):
                                return (index, .failure(exception))
                            }
                        }

                    case let .failure(exception):
                        return (index, .failure(exception))
                    }
                }
            }

            var exception: Exception?
            while let (index, result) = await taskGroup.next() {
                incrementDeliveryProgress(
                    in: conversation.value,
                    by: Floats.translationDeliveryProgressIncrement / Float(max(
                        1,
                        uniqueLanguageCodes.count
                    ))
                )

                switch result {
                case let .success((translation, audioComponent)):
                    aggregatedTranslations[index] = translation
                    aggregatedAudioComponents[index] = audioComponent

                    // TODO: Audit necessity of this when pre-recorded output exists.
                    incrementDeliveryProgress(
                        in: conversation.value,
                        by: Floats.readToFileDeliveryProgressIncrement / Float(max(
                            1,
                            uniqueLanguageCodes.count
                        ))
                    )

                // swiftlint:disable:next identifier_name
                case let .failure(_exception):
                    exception = _exception
                    taskGroup.cancelAll()
                }
            }

            if let exception { return .failure(exception) }
            return .success(())
        }

        switch taskGroupResult {
        case .success:
            let translations = aggregatedTranslations.compactMap(\.self)
            let audioComponents = aggregatedAudioComponents.compactMap(\.self)

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

        case let .failure(exception):
            return .failure(exception)
        }
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

        let users = users.filter { $0 != currentUser }
        let uniqueLanguageCodes = users.map(\.languageCode).unique
        let enhancementConfig = await getEnhancementConfiguration(
            for: conversation.value,
            isAudioMessage: false,
            userCount: users.count
        )

        let translateResults = await uniqueLanguageCodes.parallelMap {
            await networking.hostedTranslation.translate(
                .init(text),
                with: .init(
                    from: currentUser.languageCode,
                    to: $0
                ),
                enhance: enhancementConfig
            )
        }

        switch translateResults {
        case let .success(translations):
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

        case let .failure(exception):
            return .failure(exception)
        }
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

                let newParticipants = conversation.participants.map {
                    Participant(
                        userID: $0.userID,
                        hasDeletedConversation: false,
                        isTyping: $0.isTyping
                    )
                }

                guard newParticipants
                    .map(\.hasDeletedConversation) != conversation
                    .participants
                    .map(\.hasDeletedConversation) else {
                    return await addMessage(
                        message,
                        to: conversation
                    )
                }

                incrementDeliveryProgress(
                    in: conversation,
                    by: Floats.updateValueDeliveryProgressIncrement
                )

                do {
                    return try await addMessage(
                        message,
                        to: conversation.update(
                            \.participants,
                            to: newParticipants
                        )
                    )
                } catch {
                    clientSession.user.startObservingCurrentUserChanges()
                    return .failure(error)
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

    @MainActor
    private func getEnhancementConfiguration(
        for conversation: Conversation?,
        isAudioMessage: Bool,
        userCount: Int
    ) -> EnhancementConfiguration? {
        guard clientSession
            .user
            .currentUser?
            .aiEnhancedTranslationsEnabled == true else { return nil }

        // swiftlint:disable:next line_length
        let audioMessageContext = "This is the transcription of an audio message. If you spot any red flags grammatically or coherence-wise, please correct them."

        guard let messageReadout = conversation?.messageReadout else {
            return isAudioMessage ? .init(
                additionalContext: audioMessageContext
            ) : nil
        }

        let additionalContext = isAudioMessage ? audioMessageContext : ""
        return .init( // swiftlint:disable line_length
            additionalContext: "\(additionalContext)\n" + """
            Attached is a readout of the most recent messages in this conversation, sorted by latest (descending) send date.
            Ensure the addressee is spoken to with pronouns consistent in gender and number used in previous messages from 'You'.
            If needed, use the participant names to infer the proper gender to employ, but ONLY after not having reached a definitive conclusion based on the gender used in previous messages.
            Maintain the same register and tone as used by 'You' throughout the conversation.
            -----
            BEGIN MESSAGE READOUT:
            \(messageReadout)
            """
        ) // swiftlint:enable line_length
    }

    private func incrementDeliveryProgress(in conversation: Conversation?, by: Float) {
        guard shouldAnimateDeliveryProgress(in: conversation) else { return }
        Task { @MainActor in
            clientSession.deliveryProgressIndicator?.incrementDeliveryProgress(by: by)
        }
    }

    private func shouldAnimateDeliveryProgress(in conversation: Conversation?) -> Bool {
        clientSession.conversation.currentConversation?.id.key == conversation?.id.key
    }
}

@MainActor
private extension Conversation {
    var messageReadout: String? {
        guard let messages else { return nil }

        let knownUsersByID = Dictionary(
            UserCache.knownUsers.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var messageStrings = [String]()
        for message in messages.sortedByDescendingSentDate where message.contentType == .text {
            guard let matchingUser = knownUsersByID[message.fromAccountID] else { continue }

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

        guard !messageStrings.isEmpty else { return nil }
        messageStrings.removeFirst()
        return messageStrings.isEmpty ? nil : messageStrings.joined(separator: "\n")
    }
}

// swiftlint:enable file_length type_body_length
