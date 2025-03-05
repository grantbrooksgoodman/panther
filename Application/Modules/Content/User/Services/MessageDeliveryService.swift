//
//  MessageDeliveryService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 06/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Translator

// wiftlint:disable:next type_body_length
public final class MessageDeliveryService {
    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.notificationCenter) private var notificationCenter: NotificationCenter
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    public private(set) var isSendingMessage = false {
        didSet { didSetIsSendingMessage() }
    }

    private var uponIsSendingMessageChangedToFalse = [MessageDeliveryServiceEffectID: () -> Void]()
    private var uponIsSendingMessageChangedToTrue = [MessageDeliveryServiceEffectID: () -> Void]()

    // MARK: - Object Lifecycle

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
    public func addEffectUponIsSendingMessage(
        changedTo state: Bool,
        id: MessageDeliveryServiceEffectID,
        _ effect: @escaping () -> Void
    ) {
        guard state else {
            uponIsSendingMessageChangedToFalse[id] = effect
            return
        }

        uponIsSendingMessageChangedToTrue[id] = effect
    }

    // MARK: - Send Audio Message

    public func sendAudioMessage(_ inputFile: AudioFile) async -> Exception? {
        let fullConversation = clientSession.conversation.fullConversation
        let selectedContactPairs = chatPageViewService.recipientBar?.contactSelectionUI.selectedContactPairs
        let users = (fullConversation?.users ?? (selectedContactPairs ?? []).users).unique

        guard !users.isEmpty else { return nil }

        isSendingMessage = true
        chatPageViewService.inputBar?.toggleSendingUI(on: true)
        chatPageViewService.recipientBar?.layout.setIsUserInteractionEnabled(false)

        typealias Strings = AppConstants.Strings.MessageSessionService
        notificationCenter.addObserver(
            self,
            selector: #selector(postedTranscriptionSucceededNotification(_:)),
            name: .init(Strings.audioMessageTranscriptionSucceededNotificationName),
            object: nil
        )

        let sendAudioMessageResult = await clientSession.message.sendAudioMessage(
            inputFile,
            toUsers: users,
            inConversation: (fullConversation?.isMock ?? true) ? nil : fullConversation
        )

        chatPageViewService.inputBar?.configureInputBar(forceUpdate: true)
        chatPageViewService.inputBar?.toggleSendingUI(on: false)
        isSendingMessage = false
        if clientSession.conversation.currentConversation?.id.key == fullConversation?.id.key {
            chatPageViewService.deliveryProgressIndicator?.stopAnimatingDeliveryProgress()
        }

        switch sendAudioMessageResult {
        case let .success(conversation):
            services.analytics.logEvent(.sendAudioMessage)

            if let currentConversation = clientSession.conversation.currentConversation,
               !currentConversation.isMock {
                guard currentConversation.id.key == conversation.id.key else { return nil }
            }

            clientSession.conversation.setCurrentConversation(conversation)
            chatPageViewService.reloadCollectionView()
            return nil

        case let .failure(exception):
            chatPageViewService.recipientBar?.layout.setIsUserInteractionEnabled(true)
            return exception
        }
    }

    // MARK: - Send Media Message

    public func sendMediaMessage(_ mediaFile: MediaFile) async -> Exception? {
        let fullConversation = clientSession.conversation.fullConversation
        let selectedContactPairs = chatPageViewService.recipientBar?.contactSelectionUI.selectedContactPairs
        let users = (fullConversation?.users ?? (selectedContactPairs ?? []).users).unique

        guard !users.isEmpty else { return nil }

        services.haptics.generateFeedback(.medium)
        addMockMessageToCurrentConversation(audioFile: nil, mediaFile: mediaFile, text: nil)

        isSendingMessage = true
        chatPageViewService.inputBar?.toggleSendingUI(on: true, clearInputTextViewText: false)
        chatPageViewService.deliveryProgressIndicator?.startAnimatingDeliveryProgress()

        let sendMediaMessageResult = await clientSession.message.sendMediaMessage(
            mediaFile,
            toUsers: users,
            inConversation: (fullConversation?.isMock ?? true) ? nil : fullConversation
        )

        chatPageViewService.inputBar?.configureInputBar(forceUpdate: true)
        chatPageViewService.inputBar?.toggleSendingUI(on: false)
        isSendingMessage = false
        if clientSession.conversation.currentConversation?.id.key == fullConversation?.id.key {
            chatPageViewService.deliveryProgressIndicator?.stopAnimatingDeliveryProgress()
        }

        switch sendMediaMessageResult {
        case let .success(conversation):
            services.analytics.logEvent(.sendMediaMessage)

            if let currentConversation = clientSession.conversation.currentConversation,
               !currentConversation.isMock {
                guard currentConversation.id.key == conversation.id.key else { return nil }
            }

            clientSession.conversation.setCurrentConversation(conversation)
            chatPageViewService.reloadCollectionView()
            return nil

        case let .failure(exception):
            return exception
        }
    }

    // MARK: - Send Text Message

    public func sendTextMessage(_ text: String) async -> Exception? {
        let fullConversation = clientSession.conversation.fullConversation
        let selectedContactPairs = chatPageViewService.recipientBar?.contactSelectionUI.selectedContactPairs
        let users = (fullConversation?.users ?? (selectedContactPairs ?? []).users).unique

        guard !users.isEmpty,
              !text.isBlank else { return nil }

        services.haptics.generateFeedback(.medium)
        addMockMessageToCurrentConversation(audioFile: nil, mediaFile: nil, text: text)

        isSendingMessage = true
        chatPageViewService.inputBar?.toggleSendingUI(on: true)
        chatPageViewService.deliveryProgressIndicator?.startAnimatingDeliveryProgress()

        let sendTextMessageResult = await clientSession.message.sendTextMessage(
            text,
            toUsers: users,
            inConversation: (fullConversation?.isMock ?? true) ? nil : fullConversation
        )

        chatPageViewService.inputBar?.configureInputBar(forceUpdate: true)
        chatPageViewService.inputBar?.toggleSendingUI(on: false)
        isSendingMessage = false
        if clientSession.conversation.currentConversation?.id.key == fullConversation?.id.key {
            chatPageViewService.deliveryProgressIndicator?.stopAnimatingDeliveryProgress()
        }

        switch sendTextMessageResult {
        case let .success(conversation):
            services.analytics.logEvent(.sendTextMessage)

            if let currentConversation = clientSession.conversation.currentConversation,
               !currentConversation.isMock {
                guard currentConversation.id.key == conversation.id.key else { return nil }
            }

            clientSession.conversation.setCurrentConversation(conversation)
            chatPageViewService.reloadCollectionView()
            return nil

        case let .failure(exception):
            return exception
        }
    }

    // MARK: - Auxiliary

    private func addMockMessageToCurrentConversation(
        audioFile: AudioFile?,
        mediaFile: MediaFile?,
        text: String?
    ) {
        assert(audioFile != nil || mediaFile != nil || text != nil, "No values provided.")

        guard let conversation = clientSession.conversation.fullConversation,
              let currentUser = clientSession.user.currentUser else { return }

        var messages = conversation.messages ?? []

        let mockTranslation: Translation = .init(
            input: .init(text ?? ""),
            output: text ?? "",
            languagePair: .system
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
                contentType: .media(.audio(.m4a)),
                richContent: .audio([mockAudioMessageReference]),
                translations: [mockTranslation],
                readDate: nil,
                sentDate: Date()
            ))
        } else if let mediaFile {
            messages.append(.init(
                CommonConstants.newMessageID,
                fromAccountID: currentUser.id,
                contentType: .media(mediaFile.fileExtension),
                richContent: .media(mediaFile),
                translations: nil,
                readDate: nil,
                sentDate: Date()
            ))
        } else {
            messages.append(.init(
                CommonConstants.newMessageID,
                fromAccountID: currentUser.id,
                contentType: .text,
                richContent: nil,
                translations: [mockTranslation],
                readDate: nil,
                sentDate: Date()
            ))
        }

        let newConversation: Conversation = .init(
            conversation.id,
            messageIDs: conversation.messageIDs,
            messages: messages,
            metadata: conversation.metadata,
            participants: conversation.participants,
            reactionMetadata: conversation.reactionMetadata,
            users: conversation.users
        )

        if let currentConversation = clientSession.conversation.fullConversation,
           !currentConversation.isMock {
            guard currentConversation.id.key == conversation.id.key else { return }
        }

        clientSession.conversation.setCurrentConversation(newConversation)
        chatPageViewService.recipientBar?.layout.removeFromSuperview()
        chatPageViewService.reloadCollectionView()
        Observables.firstMessageSentInNewChat.trigger()
    }

    private func didSetIsSendingMessage() {
        switch isSendingMessage {
        case true:
            ContextMenuInteraction.setCanBegin(false)
            guard !uponIsSendingMessageChangedToTrue.isEmpty else { return }

            Logger.log(.init(
                "Running effects for change of \"isSendingMessage\" to TRUE.",
                extraParams: ["EnqueuedEffectIDs": uponIsSendingMessageChangedToTrue.keys.map(\.rawValue)],
                metadata: [self, #file, #function, #line]
            ))

            uponIsSendingMessageChangedToTrue.values.forEach { $0() }
            uponIsSendingMessageChangedToTrue = .init()

        case false:
            ContextMenuInteraction.setCanBegin(true)
            guard !uponIsSendingMessageChangedToFalse.isEmpty else { return }

            Logger.log(.init(
                "Running effects for change of \"isSendingMessage\" to FALSE.",
                extraParams: ["EnqueuedEffectIDs": uponIsSendingMessageChangedToFalse.keys.map(\.rawValue)],
                metadata: [self, #file, #function, #line]
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
              let inputFile = userInfo[Strings.inputFileNotificationUserInfoKey] as? AudioFile else { return }

        defer {
            notificationCenter.removeObserver(
                self,
                name: .init(Strings.audioMessageTranscriptionSucceededNotificationName),
                object: nil
            )
        }

        guard conversationIDKey == clientSession.conversation.currentConversation?.id.key else { return }
        addMockMessageToCurrentConversation(audioFile: inputFile, mediaFile: nil, text: nil)
    }
}
