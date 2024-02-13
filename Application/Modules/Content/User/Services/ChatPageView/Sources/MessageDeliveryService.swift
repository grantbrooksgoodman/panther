//
//  MessageDeliveryService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 06/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import Redux
import Translator

public final class MessageDeliveryService {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.MessageDeliveryService

    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.notificationCenter) private var notificationCenter: NotificationCenter
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    public private(set) var isSendingMessage = false {
        didSet { didSetIsSendingMessage() }
    }

    private let viewController: ChatPageViewController

    private var uponIsSendingMessageChangedToFalse = [MessageDeliveryServiceEffectID: () -> Void]()
    private var uponIsSendingMessageChangedToTrue = [MessageDeliveryServiceEffectID: () -> Void]()

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

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
        guard let fullConversation = clientSession.conversation.fullConversation,
              let users = fullConversation.users else { return nil }

        isSendingMessage = true
        toggleSendingUI(on: true)

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
            inConversation: fullConversation
        )

        chatPageViewService.inputBar?.configureInputBar(forceUpdate: true)
        toggleSendingUI(on: false)
        isSendingMessage = false

        switch sendAudioMessageResult {
        case let .success(conversation):
            if await viewController.currentConversation?.id.key == conversation.id.key {
                chatPageViewService.deliveryProgressIndicator?.stopAnimatingDeliveryProgress()
            }

            guard clientSession.conversation.currentConversation?.id.key == conversation.id.key else { return nil }
            chatPageViewService.menu?.dismissMenu()
            clientSession.conversation.setCurrentConversation(conversation)
            chatPageViewService.reloadCollectionView()
            return nil

        case let .failure(exception):
            return exception
        }
    }

    // MARK: - Send Text Message

    public func sendTextMessage(_ text: String) async -> Exception? {
        guard let fullConversation = clientSession.conversation.fullConversation,
              let users = fullConversation.users,
              !text.isBlank else { return nil }

        services.haptics.generateFeedback(.medium)
        addMockMessageToCurrentConversation(audioFile: nil, text: text)

        isSendingMessage = true
        toggleSendingUI(on: true)
        chatPageViewService.deliveryProgressIndicator?.startAnimatingDeliveryProgress()

        let sendTextMessageResult = await clientSession.message.sendTextMessage(
            text,
            toUsers: users,
            inConversation: fullConversation
        )

        chatPageViewService.inputBar?.configureInputBar(forceUpdate: true)
        toggleSendingUI(on: false)
        isSendingMessage = false
        if await viewController.currentConversation?.id.key == fullConversation.id.key {
            chatPageViewService.deliveryProgressIndicator?.stopAnimatingDeliveryProgress()
        }

        switch sendTextMessageResult {
        case let .success(conversation):
            guard clientSession.conversation.currentConversation?.id.key == conversation.id.key else { return nil }
            chatPageViewService.menu?.dismissMenu()
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
        text: String?
    ) {
        assert(audioFile != nil || text != nil, "No values provided.")

        guard let conversation = viewController.currentConversation,
              var messages = conversation.messages,
              let currentUser = clientSession.user.currentUser else { return }

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
                UserContentConstants.newMessageID,
                fromAccountID: currentUser.id,
                hasAudioComponent: true,
                audioComponents: [mockAudioMessageReference],
                translations: [mockTranslation],
                readDate: nil,
                sentDate: Date()
            ))
        } else {
            messages.append(.init(
                UserContentConstants.newMessageID,
                fromAccountID: currentUser.id,
                hasAudioComponent: false,
                audioComponents: nil,
                translations: [mockTranslation],
                readDate: nil,
                sentDate: Date()
            ))
        }

        let newConversation: Conversation = .init(
            conversation.id,
            messageIDs: conversation.messageIDs,
            messages: messages,
            lastModifiedDate: conversation.lastModifiedDate,
            participants: conversation.participants,
            users: conversation.users
        )

        guard clientSession.conversation.currentConversation?.id.key == conversation.id.key else { return }
        chatPageViewService.menu?.dismissMenu()
        clientSession.conversation.setCurrentConversation(newConversation)
        chatPageViewService.reloadCollectionView()
    }

    private func didSetIsSendingMessage() {
        switch isSendingMessage {
        case true:
            guard !uponIsSendingMessageChangedToTrue.isEmpty else { return }
            uponIsSendingMessageChangedToTrue.values.forEach { $0() }
            uponIsSendingMessageChangedToTrue = .init()

        case false:
            guard !uponIsSendingMessageChangedToFalse.isEmpty else { return }
            uponIsSendingMessageChangedToFalse.values.forEach { $0() }
            uponIsSendingMessageChangedToFalse = .init()
        }
    }

    @objc
    private func postedTranscriptionSucceededNotification(_ notification: Notification) {
        typealias Strings = AppConstants.Strings.MessageSessionService

        // TODO: Make use of the transcription for menu item.
        guard let userInfo = notification.userInfo,
              let inputFile = userInfo[Strings.inputFileNotificationUserInfoKey] as? AudioFile /* ,
               let transcription = userInfo[Strings.transcriptionNotificationUserInfoKey] as? String */ else { return }

        addMockMessageToCurrentConversation(audioFile: inputFile, text: nil)

        notificationCenter.removeObserver(
            self,
            name: .init(Strings.audioMessageTranscriptionSucceededNotificationName),
            object: nil
        )
    }

    private func toggleSendingUI(on: Bool) {
        Task { @MainActor in
            if on {
                viewController.messageInputBar.inputTextView.text = ""
                viewController.messageInputBar.sendButton.startAnimating()
            } else {
                viewController.messageInputBar.sendButton.stopAnimating()
            }

            viewController.messageInputBar.inputTextView.tintColor = on ? UIColor(Colors.inputBarInputTextViewTint) : .accent
            viewController.messageInputBar.sendButton.isUserInteractionEnabled = on ? false : true
        }
    }
}
