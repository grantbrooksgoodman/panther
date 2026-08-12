//
//  MessageDeliveryService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 06/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Translator

/// The service that sends messages from the chat page.
///
/// Use ``MessageDeliveryService`` to send text, audio, and media messages to the current
/// conversation's users – or, when composing a new conversation, to the recipients selected
/// in the recipient bar. Sends to existing conversations are staged in the outbox, so failed
/// messages can be retried; sends that create a new conversation optimistically insert a mock
/// message instead. While a send is in flight, ``isSendingMessage`` is `true` and context
/// menu interactions are disabled.
@MainActor
final class MessageDeliveryService {
    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    /// A Boolean value that indicates whether a message send is in flight.
    private(set) var isSendingMessage = false {
        didSet { didSetIsSendingMessage() }
    }

    @SharedEvent(\.audioMessageTranscriptionSucceeded) private var audioMessageTranscriptionSucceeded
    private var eventChangeTask: Task<Void, Never>?
    @SharedEvent(\.firstMessageSentInNewChat) private var firstMessageSentInNewChat
    private var uponIsSendingMessageChangedToFalse = [MessageDeliveryServiceEffectID: () -> Void]()
    private var uponIsSendingMessageChangedToTrue = [MessageDeliveryServiceEffectID: () -> Void]()

    // MARK: - Computed Properties

    private var conversation: Conversation? {
        clientSession.entity.conversation.currentConversation
    }

    private var conversationContext: (value: Conversation?, isPenPalsConversation: Bool) {
        ((conversation?.isMock ?? true) ? nil : conversation, isPenPalsConversation)
    }

    private var isExistingConversation: Bool {
        conversation != nil && conversation?.isMock != true
    }

    private var isPenPalsConversation: Bool {
        // TODO: Figure out a better way to confirm isPenPalsConversation. Can be spoofed with genuine contact names.
        (selectedContactPairs?.map(\.contact.fullName) ?? []).containsAnyString(in: users.map(\.penPalsName)) ||
            conversation?.metadata.isPenPalsConversation == true
    }

    private var selectedContactPairs: [ContactPair]? {
        chatPageViewService.recipientBar?.contactSelectionUI.selectedContactPairs
    }

    private var users: [User] {
        (conversation?.users ?? (selectedContactPairs ?? []).users).unique
    }

    // MARK: - Object Lifecycle

    @MainActor
    deinit {
        eventChangeTask?.cancel()
        eventChangeTask = nil
    }

    // MARK: - Add Effect

    /// Registers an effect to run once, the next time ``isSendingMessage`` is set to the given
    /// value.
    ///
    /// The effect is cleared after it runs. Registering a new effect with the same identifier
    /// and target value replaces the existing one.
    ///
    /// - Parameters:
    ///   - state: The value of ``isSendingMessage`` that triggers the effect.
    ///   - id: The identifier under which to register the effect.
    ///   - effect: The effect to run.
    func addEffectUponIsSendingMessage(
        changedTo state: Bool,
        id: MessageDeliveryServiceEffectID,
        _ effect: @escaping () -> Void
    ) {
        guard state else { return uponIsSendingMessageChangedToFalse[id] = effect }
        uponIsSendingMessageChangedToTrue[id] = effect
    }

    // MARK: - Send Audio Message

    /// Sends an audio message to the current recipients.
    ///
    /// Sends to an existing conversation are staged in the outbox and marked failed if
    /// delivery fails; when the send creates a new conversation, a mock message is
    /// optimistically inserted once the message's transcription succeeds, and delivery
    /// failures are thrown instead. If no recipients are resolved, this method does nothing.
    ///
    /// - Parameters:
    ///   - inputFile: The audio file to send.
    ///   - transcription: The transcription of the audio, or `nil` if unavailable. The
    ///     default is `nil`.
    ///
    /// - Throws: An `Exception` if delivery fails for a message that was not staged in the
    ///   outbox.
    func sendAudioMessage(
        _ inputFile: AudioFile,
        transcription: String? = nil
    ) async throws(Exception) {
        guard !users.isEmpty else { return }

        isSendingMessage = true
        chatPageViewService.inputBar?.toggleSendingUI(on: true)

        Task { @MainActor in
            @Dependency(\.chatPageViewService.recipientBar?.layout) var recipientBarLayoutService: RecipientBarLayoutService?
            recipientBarLayoutService?.setIsUserInteractionEnabled(false)
        }

        var outboxEntryID: String?

        if isExistingConversation,
           let conversation,
           let currentUser = clientSession.entity.user.currentUser {
            do {
                let payloadFileName = try clientSession.outbox.storePayloadFile(
                    from: inputFile.url
                )

                let entry = OutboxEntry(
                    conversationIDKey: conversation.id.key,
                    createdDate: .now,
                    fromAccountID: currentUser.id,
                    id: "outbox-\(UUID().uuidString)",
                    isPenPalsConversation: isPenPalsConversation,
                    payload: .audio(inputFileName: payloadFileName),
                    recipientUserIDs: users.map(\.id),
                    attemptCount: 1,
                    lastAttemptDate: .now,
                    state: .sending,
                    transcription: transcription
                )

                outboxEntryID = entry.id
                clientSession.outbox.enqueue(entry)
                hideRecipientBar()
            } catch {
                Logger.log(
                    .init(
                        error,
                        metadata: .init(sender: self)
                    )
                )
            }
        }

        // Register the notification handler for the draft path only.
        if outboxEntryID == nil {
            eventChangeTask = Task { [weak self] in
                guard let self else { return }
                for await transcriptionData in audioMessageTranscriptionSucceeded.events {
                    defer {
                        eventChangeTask?.cancel()
                        eventChangeTask = nil
                    }

                    guard transcriptionData.conversationIDKey == conversation?.id.key else { return }
                    addMockMessageToCurrentConversation(
                        audioFile: transcriptionData.inputFile,
                        mediaFile: nil,
                        text: nil,
                        isPenPalsConversation: transcriptionData.isPenPalsConversation
                    )
                }
            }
        }

        defer { cleanUpAfterSend() }

        do {
            let conversation = try await clientSession.entity.message.sendAudioMessage(
                inputFile,
                transcription: transcription,
                toUsers: users,
                inConversation: conversationContext
            )

            if let outboxEntryID {
                clientSession.outbox.remove(id: outboxEntryID)
            }

            services.analytics.logEvent(.sendAudioMessage)
            setCurrentConversationIfApplicable(conversation)
        } catch {
            if let outboxEntryID {
                clientSession.outbox.markFailed(id: outboxEntryID)
                Logger.log(error)
            } else {
                Task { @MainActor in
                    @Dependency(\.chatPageViewService.recipientBar?.layout) var recipientBarLayoutService: RecipientBarLayoutService?
                    recipientBarLayoutService?.setIsUserInteractionEnabled(true)
                }

                throw error
            }
        }
    }

    // MARK: - Send Media Message

    /// Sends a media message to the current recipients.
    ///
    /// Sends to an existing conversation are staged in the outbox and marked failed if
    /// delivery fails; when the send creates a new conversation, a mock message is
    /// optimistically inserted, and delivery failures are thrown instead. If no recipients
    /// are resolved, this method does nothing.
    ///
    /// - Parameter mediaFile: The media file to send.
    ///
    /// - Throws: An `Exception` if delivery fails for a message that was not staged in the
    ///   outbox.
    func sendMediaMessage(
        _ mediaFile: MediaFile
    ) async throws(Exception) {
        guard !users.isEmpty else { return }

        services.haptics.generateFeedback(.medium)

        var outboxEntryID: String?

        if isExistingConversation,
           let conversation,
           let currentUser = clientSession.entity.user.currentUser {
            do {
                let payloadFileName = try clientSession.outbox.storePayloadFile(
                    from: mediaFile.localPathURL
                )

                let entry = OutboxEntry(
                    conversationIDKey: conversation.id.key,
                    createdDate: .now,
                    fromAccountID: currentUser.id,
                    id: "outbox-\(UUID().uuidString)",
                    isPenPalsConversation: isPenPalsConversation,
                    payload: .media(
                        fileName: payloadFileName,
                        fileExtension: mediaFile.fileExtension
                    ),
                    recipientUserIDs: users.map(\.id),
                    attemptCount: 1,
                    lastAttemptDate: .now,
                    state: .sending
                )

                outboxEntryID = entry.id
                clientSession.outbox.enqueue(entry)
                hideRecipientBar()
            } catch {
                Logger.log(
                    .init(
                        error,
                        metadata: .init(sender: self)
                    )
                )
            }
        } else {
            addMockMessageToCurrentConversation(
                audioFile: nil,
                mediaFile: mediaFile,
                text: nil,
                isPenPalsConversation: isPenPalsConversation
            )
        }

        isSendingMessage = true
        chatPageViewService.inputBar?.toggleSendingUI(
            on: true,
            clearInputTextViewText: false
        )

        chatPageViewService.deliveryProgressIndicator?.startAnimatingDeliveryProgress()
        defer { cleanUpAfterSend() }

        do {
            let conversation = try await clientSession.entity.message.sendMediaMessage(
                mediaFile,
                toUsers: users,
                inConversation: conversationContext
            )

            if let outboxEntryID {
                clientSession.outbox.remove(id: outboxEntryID)
            }

            services.analytics.logEvent(.sendMediaMessage)
            setCurrentConversationIfApplicable(conversation)
        } catch {
            if let outboxEntryID {
                clientSession.outbox.markFailed(id: outboxEntryID)
                Logger.log(error)
            } else {
                throw error
            }
        }
    }

    // MARK: - Send Text Message

    /// Sends a text message to the current recipients.
    ///
    /// Sends to an existing conversation are staged in the outbox and marked failed if
    /// delivery fails; when the send creates a new conversation, a mock message is
    /// optimistically inserted, and delivery failures are thrown instead. If the text is
    /// blank or no recipients are resolved, this method does nothing.
    ///
    /// - Parameter text: The text to send.
    ///
    /// - Throws: An `Exception` if delivery fails for a message that was not staged in the
    ///   outbox.
    func sendTextMessage(
        _ text: String
    ) async throws(Exception) {
        guard !users.isEmpty,
              !text.isBlank else { return }

        services.haptics.generateFeedback(.medium)
        var outboxEntryID: String?

        if isExistingConversation,
           let conversation,
           let currentUser = clientSession.entity.user.currentUser {
            let entry = OutboxEntry(
                conversationIDKey: conversation.id.key,
                createdDate: .now,
                fromAccountID: currentUser.id,
                id: "outbox-\(UUID().uuidString)",
                isPenPalsConversation: isPenPalsConversation,
                payload: .text(text),
                recipientUserIDs: users.map(\.id),
                attemptCount: 1,
                lastAttemptDate: .now,
                state: .sending
            )

            outboxEntryID = entry.id
            clientSession.outbox.enqueue(entry)
            hideRecipientBar()
        } else {
            addMockMessageToCurrentConversation(
                audioFile: nil,
                mediaFile: nil,
                text: text,
                isPenPalsConversation: isPenPalsConversation
            )
        }

        isSendingMessage = true
        chatPageViewService.inputBar?.toggleSendingUI(on: true)
        chatPageViewService.deliveryProgressIndicator?.startAnimatingDeliveryProgress()
        defer { cleanUpAfterSend() }

        do {
            let conversation = try await clientSession.entity.message.sendTextMessage(
                text,
                toUsers: users,
                inConversation: conversationContext
            )

            if let outboxEntryID {
                clientSession.outbox.remove(id: outboxEntryID)
            }

            services.analytics.logEvent(.sendTextMessage)
            setCurrentConversationIfApplicable(conversation)
        } catch {
            if let outboxEntryID {
                clientSession.outbox.markFailed(id: outboxEntryID)
                Logger.log(error)
            } else {
                throw error
            }
        }
    }

    // MARK: - Auxiliary

    private func addMockMessageToCurrentConversation(
        audioFile: AudioFile?,
        mediaFile: MediaFile?,
        text: String?,
        isPenPalsConversation: Bool
    ) {
        assert(
            audioFile != nil || mediaFile != nil || text != nil,
            "No values provided."
        )

        guard let conversation = clientSession.entity.conversation.currentConversation,
              let currentUser = clientSession.entity.user.currentUser else { return }

        var messages = conversation.messages ?? []
        let mockTranslation: Translation = .init(
            input: .init(text ?? ""),
            output: text ?? "",
            languagePair: .init(
                from: currentUser.languageCode,
                to: currentUser.languageCode
            )
        )

        if let audioFile {
            let mockAudioMessageReference: AudioMessageReference = .init(
                translation: mockTranslation,
                original: audioFile,
                translated: audioFile,
                translatedDirectoryPath: ""
            )

            messages.append(.init(
                CommonConstants.newMessageID,
                fromAccountID: currentUser.id,
                contentType: .audio(.m4a),
                richContent: .audio([mockAudioMessageReference]),
                translationReferences: [mockTranslation.reference],
                translations: [mockTranslation],
                readReceipts: nil,
                sentDate: Date.now
            ))
        } else if let mediaFile {
            messages.append(.init(
                CommonConstants.newMessageID,
                fromAccountID: currentUser.id,
                contentType: .media(
                    id: mediaFile.encodedHash.shortened,
                    extension: mediaFile.fileExtension
                ),
                richContent: .media(mediaFile),
                translationReferences: nil,
                translations: nil,
                readReceipts: nil,
                sentDate: Date.now
            ))
        } else {
            messages.append(.init(
                CommonConstants.newMessageID,
                fromAccountID: currentUser.id,
                contentType: .text,
                richContent: nil,
                translationReferences: [mockTranslation.reference],
                translations: [mockTranslation],
                readReceipts: nil,
                sentDate: Date.now
            ))
        }

        // Optimistic insert before remote send; didWrite does not apply.
        clientSession.store.upsertMessages(Set(messages))
        let newConversation = conversation
            .copying(messageIDs: messages.map(\.id))
            .copying(
                metadata: conversation.metadata.copyWith(
                    isPenPalsConversation: isPenPalsConversation
                )
            )

        if let currentConversation = clientSession.entity.conversation.currentConversation,
           !currentConversation.isMock {
            guard currentConversation.id.key == conversation.id.key else { return }
        }

        clientSession.entity.conversation.setCurrentConversation(newConversation)
        Task { @MainActor in
            hideRecipientBar()
            chatPageViewService.reloadCollectionView()
        }
    }

    private func cleanUpAfterSend() {
        isSendingMessage = false
        chatPageViewService.inputBar?.configureInputBar(forceUpdate: true)
        chatPageViewService.inputBar?.toggleSendingUI(on: false)

        if clientSession.entity.conversation.currentConversation?.id.key == conversation?.id.key {
            chatPageViewService
                .deliveryProgressIndicator?
                .stopAnimatingDeliveryProgress()
        }
    }

    private func didSetIsSendingMessage() {
        switch isSendingMessage {
        case true:
            ContextMenuInteraction.setCanBegin(false)
            guard !uponIsSendingMessageChangedToTrue.isEmpty else { return }

            Logger.log(.init(
                "Running effects for change of \"isSendingMessage\" to TRUE.",
                isReportable: false,
                userInfo: ["EnqueuedEffectIDs": uponIsSendingMessageChangedToTrue.keys.map(\.rawValue)],
                metadata: .init(sender: self)
            ))

            uponIsSendingMessageChangedToTrue.values.forEach { $0() }
            uponIsSendingMessageChangedToTrue = .init()

        case false:
            ContextMenuInteraction.setCanBegin(true)
            guard !uponIsSendingMessageChangedToFalse.isEmpty else { return }

            Logger.log(.init(
                "Running effects for change of \"isSendingMessage\" to FALSE.",
                isReportable: false,
                userInfo: ["EnqueuedEffectIDs": uponIsSendingMessageChangedToFalse.keys.map(\.rawValue)],
                metadata: .init(sender: self)
            ))

            uponIsSendingMessageChangedToFalse.values.forEach { $0() }
            uponIsSendingMessageChangedToFalse = .init()
        }
    }

    private func hideRecipientBar() {
        Task { @MainActor in
            @Dependency(\.chatPageViewService.recipientBar?.layout) var recipientBarLayoutService: RecipientBarLayoutService?
            recipientBarLayoutService?.removeFromSuperview()
        }

        firstMessageSentInNewChat.send()
    }

    private func setCurrentConversationIfApplicable(
        _ conversation: Conversation
    ) {
        if let currentConversation = clientSession.entity.conversation.currentConversation,
           !currentConversation.isMock {
            guard currentConversation.id.key == conversation.id.key else { return }
        }

        clientSession.entity.conversation.setCurrentConversation(conversation)
        chatPageViewService.reloadCollectionView()
    }
}

// swiftlint:enable file_length type_body_length
