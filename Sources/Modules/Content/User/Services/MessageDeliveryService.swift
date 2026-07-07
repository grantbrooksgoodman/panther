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

@MainActor
final class MessageDeliveryService {
    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.notificationCenter) private var notificationCenter: NotificationCenter
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    private(set) var isSendingMessage = false {
        didSet { didSetIsSendingMessage() }
    }

    private var uponIsSendingMessageChangedToFalse = [MessageDeliveryServiceEffectID: () -> Void]()
    private var uponIsSendingMessageChangedToTrue = [MessageDeliveryServiceEffectID: () -> Void]()

    // MARK: - Computed Properties

    private var conversation: Conversation? {
        clientSession.conversation.currentConversation
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
        typealias Strings = AppConstants.Strings.MessageSessionService
        notificationCenter.removeObserver(
            self,
            name: .init(Strings.audioMessageTranscriptionSucceededNotificationName),
            object: nil
        )
    }

    // MARK: - Add Effect

    /// Adds an effect to be run once, upon a change in value of `isSendingMessage`.
    func addEffectUponIsSendingMessage(
        changedTo state: Bool,
        id: MessageDeliveryServiceEffectID,
        _ effect: @escaping () -> Void
    ) {
        guard state else { return uponIsSendingMessageChangedToFalse[id] = effect }
        uponIsSendingMessageChangedToTrue[id] = effect
    }

    // MARK: - Send Audio Message

    func sendAudioMessage(
        _ inputFile: AudioFile
    ) async throws(Exception) {
        guard !users.isEmpty else { return }

        isSendingMessage = true
        chatPageViewService.inputBar?.toggleSendingUI(on: true)

        Task { @MainActor in
            @Dependency(\.chatPageViewService.recipientBar?.layout) var recipientBarLayoutService: RecipientBarLayoutService?
            recipientBarLayoutService?.setIsUserInteractionEnabled(false)
        }

        typealias Strings = AppConstants.Strings.MessageSessionService
        notificationCenter.addObserver(
            self,
            name: .init(Strings.audioMessageTranscriptionSucceededNotificationName),
            removeAfterFirstPost: true
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let conversationIDKey = userInfo[Strings.conversationIDKeyNotificationUserInfoKey] as? String,
                  let inputFile = userInfo[Strings.inputFileNotificationUserInfoKey] as? AudioFile,
                  let isPenPalsConversation = userInfo[Strings.isPenPalsConversationNotificationUserInfoKey] as? Bool else { return }

            guard conversationIDKey == self.clientSession.conversation.currentConversation?.id.key else { return }
            self.addMockMessageToCurrentConversation(
                audioFile: inputFile,
                mediaFile: nil,
                text: nil,
                isPenPalsConversation: isPenPalsConversation
            )
        }

        defer {
            isSendingMessage = false
            chatPageViewService.inputBar?.configureInputBar(forceUpdate: true)
            chatPageViewService.inputBar?.toggleSendingUI(on: false)

            if clientSession.conversation.currentConversation?.id.key == conversation?.id.key {
                chatPageViewService
                    .deliveryProgressIndicator?
                    .stopAnimatingDeliveryProgress()
            }
        }

        do {
            let conversation = try await clientSession.message.sendAudioMessage(
                inputFile,
                toUsers: users,
                inConversation: ((conversation?.isMock ?? true) ? nil : conversation, isPenPalsConversation)
            )

            services.analytics.logEvent(.sendAudioMessage)

            if let currentConversation = clientSession.conversation.currentConversation,
               !currentConversation.isMock {
                guard currentConversation.id.key == conversation.id.key else { return }
            }

            clientSession.conversation.setCurrentConversation(conversation)
            chatPageViewService.reloadCollectionView()
        } catch {
            Task { @MainActor in
                @Dependency(\.chatPageViewService.recipientBar?.layout) var recipientBarLayoutService: RecipientBarLayoutService?
                recipientBarLayoutService?.setIsUserInteractionEnabled(true)
            }

            throw error
        }
    }

    // MARK: - Send Media Message

    func sendMediaMessage(
        _ mediaFile: MediaFile
    ) async throws(Exception) {
        guard !users.isEmpty else { return }

        services.haptics.generateFeedback(.medium)
        addMockMessageToCurrentConversation(
            audioFile: nil,
            mediaFile: mediaFile,
            text: nil,
            isPenPalsConversation: isPenPalsConversation
        )

        isSendingMessage = true
        chatPageViewService.inputBar?.toggleSendingUI(
            on: true,
            clearInputTextViewText: false
        )

        chatPageViewService.deliveryProgressIndicator?.startAnimatingDeliveryProgress()

        defer {
            isSendingMessage = false
            chatPageViewService.inputBar?.configureInputBar(forceUpdate: true)
            chatPageViewService.inputBar?.toggleSendingUI(on: false)

            if clientSession.conversation.currentConversation?.id.key == conversation?.id.key {
                chatPageViewService
                    .deliveryProgressIndicator?
                    .stopAnimatingDeliveryProgress()
            }
        }

        let conversation = try await clientSession.message.sendMediaMessage(
            mediaFile,
            toUsers: users,
            inConversation: ((conversation?.isMock ?? true) ? nil : conversation, isPenPalsConversation)
        )

        services.analytics.logEvent(.sendMediaMessage)
        if let currentConversation = clientSession.conversation.currentConversation,
           !currentConversation.isMock {
            guard currentConversation.id.key == conversation.id.key else { return }
        }

        clientSession.conversation.setCurrentConversation(conversation)
        chatPageViewService.reloadCollectionView()
    }

    // MARK: - Send Text Message

    func sendTextMessage(
        _ text: String
    ) async throws(Exception) {
        guard !users.isEmpty,
              !text.isBlank else { return }

        services.haptics.generateFeedback(.medium)
        addMockMessageToCurrentConversation(
            audioFile: nil,
            mediaFile: nil,
            text: text,
            isPenPalsConversation: isPenPalsConversation
        )

        isSendingMessage = true
        chatPageViewService.inputBar?.toggleSendingUI(on: true)
        chatPageViewService.deliveryProgressIndicator?.startAnimatingDeliveryProgress()

        defer {
            isSendingMessage = false
            chatPageViewService.inputBar?.configureInputBar(forceUpdate: true)
            chatPageViewService.inputBar?.toggleSendingUI(on: false)

            if clientSession.conversation.currentConversation?.id.key == conversation?.id.key {
                chatPageViewService
                    .deliveryProgressIndicator?
                    .stopAnimatingDeliveryProgress()
            }
        }

        let conversation = try await clientSession.message.sendTextMessage(
            text,
            toUsers: users,
            inConversation: ((conversation?.isMock ?? true) ? nil : conversation, isPenPalsConversation)
        )

        services.analytics.logEvent(.sendTextMessage)
        if let currentConversation = clientSession.conversation.currentConversation,
           !currentConversation.isMock {
            guard currentConversation.id.key == conversation.id.key else { return }
        }

        clientSession.conversation.setCurrentConversation(conversation)
        chatPageViewService.reloadCollectionView()
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

        guard let conversation = clientSession.conversation.currentConversation,
              let currentUser = clientSession.user.currentUser else { return }

        var messages = conversation.messages ?? []
        let mockTranslation: Translation = .init(
            input: .init(text?.trimmingTrailingWhitespace ?? ""),
            output: text?.trimmingTrailingWhitespace ?? "",
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

        clientSession.store.upsertMessages(Set(messages))
        let newConversation = conversation
            .copying(messageIDs: messages.map(\.id))
            .copying(
                metadata: conversation.metadata.copyWith(
                    isPenPalsConversation: isPenPalsConversation
                )
            )

        if let currentConversation = clientSession.conversation.currentConversation,
           !currentConversation.isMock {
            guard currentConversation.id.key == conversation.id.key else { return }
        }

        clientSession.conversation.setCurrentConversation(newConversation)
        Task { @MainActor in
            @Dependency(\.chatPageViewService.recipientBar?.layout) var recipientBarLayoutService: RecipientBarLayoutService?
            recipientBarLayoutService?.removeFromSuperview()
            chatPageViewService.reloadCollectionView()
        }

        Observables.firstMessageSentInNewChat.trigger()
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

    @objc
    private func postedTranscriptionSucceededNotification(_ notification: Notification) {
        typealias Strings = AppConstants.Strings.MessageSessionService

        guard let userInfo = notification.userInfo,
              let conversationIDKey = userInfo[Strings.conversationIDKeyNotificationUserInfoKey] as? String,
              let inputFile = userInfo[Strings.inputFileNotificationUserInfoKey] as? AudioFile,
              let isPenPalsConversation = userInfo[Strings.isPenPalsConversationNotificationUserInfoKey] as? Bool else { return }

        defer {
            notificationCenter.removeObserver(
                self,
                name: .init(Strings.audioMessageTranscriptionSucceededNotificationName),
                object: nil
            )
        }

        guard conversationIDKey == clientSession.conversation.currentConversation?.id.key else { return }
        addMockMessageToCurrentConversation(
            audioFile: inputFile,
            mediaFile: nil,
            text: nil,
            isPenPalsConversation: isPenPalsConversation
        )
    }
}

// swiftlint:enable file_length type_body_length
