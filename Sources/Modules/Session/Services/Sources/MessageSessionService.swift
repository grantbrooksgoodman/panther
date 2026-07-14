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
    ) async throws(Exception) -> Conversation {
        guard let currentUser = clientSession.user.currentUser else {
            throw Exception(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        let transcription = try await services.audio.transcription.transcribeAudioFile(
            at: inputFile.url,
            languageCode: currentUser.languageCode
        )

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
            of: (
                Int,
                Callback<(Translation, AudioMessageReference), Exception>
            ).self
        ) { taskGroup in
            for (index, languageCode) in uniqueLanguageCodes.enumerated() {
                taskGroup.addTask { [self, transcription = transcription as String] in
                    do throws(Exception) {
                        let translation = try await networking.hostedTranslation.translate(
                            .init(transcription),
                            with: .init(
                                from: currentUser.languageCode,
                                to: languageCode
                            ),
                            enhance: enhancementConfig
                        )

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
                            let readToFileResult = await Callback.asCallback {
                                try await services.audio.textToSpeech.readToFile(
                                    text: translation.output.sanitized,
                                    languageCode: languageCode
                                )
                            }

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
                    } catch {
                        return (index, .failure(error))
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
                throw Exception(
                    "Translations fail validation.",
                    metadata: .init(sender: self)
                )
            }

            return try await createMessageAndAddToConversation(
                conversation: conversation,
                initiatingUser: currentUser,
                otherUsers: users,
                richContent: .audio(audioComponents),
                translations: translations
            )

        case let .failure(exception):
            throw exception
        }
    }

    // MARK: - Send Media Message

    func sendMediaMessage(
        _ mediaFile: MediaFile,
        toUsers users: [User],
        inConversation conversation: (value: Conversation?, isPenPalsConversation: Bool)
    ) async throws(Exception) -> Conversation {
        guard let currentUser = clientSession.user.currentUser else {
            throw Exception(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        return try await createMessageAndAddToConversation(
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
    ) async throws(Exception) -> Conversation {
        guard let currentUser = clientSession.user.currentUser else {
            throw Exception(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        var text = text
        if build.isDeveloperModeEnabled,
           await languageRecognitionService.matchConfidence(
               for: text,
               inLanguage: currentUser.languageCode
           ) < Floats.languageRecognitionServiceMatchConfidenceThreshold {
            do {
                text = try await networking.hostedTranslation.translate(
                    .init(text),
                    with: .init(from: "en", to: currentUser.languageCode),
                    enhance: getEnhancementConfiguration(
                        for: conversation.value,
                        isAudioMessage: false,
                        userCount: users.count
                    )
                ).output.sanitized
            } catch {
                Logger.log(error)
            }
        }

        let users = users.filter { $0 != currentUser }
        let uniqueLanguageCodes = users.map(\.languageCode).unique
        let enhancementConfig = await getEnhancementConfiguration(
            for: conversation.value,
            isAudioMessage: false,
            userCount: users.count
        )

        let translations = try await uniqueLanguageCodes.map { languageCode in
            try await networking.hostedTranslation.translate(
                .init(text),
                with: .init(
                    from: currentUser.languageCode,
                    to: languageCode
                ),
                enhance: enhancementConfig
            )
        }

        guard translations.isWellFormed else {
            throw Exception(
                "Translations fail validation.",
                metadata: .init(sender: self)
            )
        }

        return try await createMessageAndAddToConversation(
            conversation: conversation,
            initiatingUser: currentUser,
            otherUsers: users,
            richContent: nil,
            translations: translations
        )
    }

    // MARK: - Auxiliary

    private func createMessageAndAddToConversation(
        conversation: (value: Conversation?, isPenPalsConversation: Bool),
        initiatingUser: User,
        otherUsers: [User],
        richContent: RichMessageContent?,
        translations: [Translation]?
    ) async throws(Exception) -> Conversation {
        func addMessage(
            _ message: Message,
            to conversation: Conversation
        ) async throws(Exception) -> Conversation {
            incrementDeliveryProgress(
                in: conversation,
                by: Floats.addMessageDeliveryProgressIncrement
            )

            return try await clientSession.conversation.addMessages(
                [message],
                to: conversation
            )
        }

        func notifyUsers(
            of message: Message,
            conversationIDKey: String,
            isPenPalsConversation: Bool
        ) {
            Task.background {
                do throws(Exception) {
                    try await services.notification.notify(
                        otherUsers.filter {
                            !($0.blockedUserIDs ?? []).contains(initiatingUser.id)
                        },
                        message: message,
                        conversationIDKey: conversationIDKey,
                        isPenPalsConversation: isPenPalsConversation
                    )
                } catch {
                    Logger.log(
                        error,
                        domain: .notifications
                    )
                }

                incrementDeliveryProgress(
                    in: conversation.value,
                    by: Floats.notifyDeliveryProgressIncrement
                )
            }
        }

        incrementDeliveryProgress(
            in: conversation.value,
            by: Floats.createMessageDeliveryProgressIncrement
        )

        let message: Message
        do {
            message = try await networking.messageService.buildMessage(
                fromAccountID: initiatingUser.id,
                richContent: richContent,
                translations: translations
            )
        } catch {
            throw error
        }

        if let conversation = conversation.value {
            notifyUsers(
                of: message,
                conversationIDKey: conversation.id.key,
                isPenPalsConversation: conversation.metadata.isPenPalsConversation
            )

            // Participant un-delete is merged into the
            // willWrite(.messages) atomic fan-out.
            return try await addMessage(
                message,
                to: conversation
            )
        } else {
            var participantUsers = [initiatingUser]
            participantUsers.append(contentsOf: otherUsers)

            services.analytics.logEvent(.createNewConversation)
            incrementDeliveryProgress(
                in: conversation.value,
                by: Floats.createConversationDeliveryProgressIncrement
            )

            let createdConversation = try await networking.conversationService.createConversation(
                firstMessage: message,
                isPenPalsConversation: conversation.isPenPalsConversation,
                participants: participantUsers.map { Participant(userID: $0.id) }
            )

            notifyUsers(
                of: message,
                conversationIDKey: createdConversation.id.key,
                isPenPalsConversation: createdConversation.metadata.isPenPalsConversation
            )

            return createdConversation
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

    private func incrementDeliveryProgress(
        in conversation: Conversation?,
        by: Float
    ) {
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

        @Dependency(\.clientSession.store) var sessionStore: SessionStore
        let knownUsersByID = sessionStore.users

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
