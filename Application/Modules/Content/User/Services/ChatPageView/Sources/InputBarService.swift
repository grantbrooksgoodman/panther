//
//  InputBarService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import InputBarAccessoryView
import Redux

// swiftlint:disable:next type_body_length
public final class InputBarService {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatPageView
    private typealias Floats = AppConstants.CGFloats.ChatPageView
    private typealias Strings = AppConstants.Strings.ChatPageView

    // MARK: - Dependencies

    @Dependency(\.commonServices.audio) private var audioService: AudioService
    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.inputBarConfigService) private var inputBarConfigService: InputBarConfigService
    @Dependency(\.mainQueue) private var mainQueue: DispatchQueue

    // MARK: - Properties

    private let viewController: ChatPageViewController

    private var isStoppingRecording = false
    private var isUpdatingIsTypingForCurrentUser = false

    // MARK: - Computed Properties

    public var shouldEnableSendButton: Bool {
        let isConversationEmpty = viewController.currentConversation?.id.key == UserContentConstants.newConversationID
        let isSendButtonConfiguredForText = !inputBar.sendButton.isRecordButton
        let isTextViewTextBlank = inputBar.inputTextView.text.isBlank

        guard isSendButtonConfiguredForText else { return !isConversationEmpty }
        return !isConversationEmpty && !isTextViewTextBlank
    }

    private var inputBar: InputBarAccessoryView { viewController.messageInputBar }
    private var shouldConfigureInputBarForRecording: Bool { inputBarConfigService.canConfigureInputBarForRecording && inputBar.inputTextView.text.isEmpty }

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Configure Input Bar

    public func configureInputBar(
        forRecording: Bool? = nil,
        forceUpdate: Bool = false
    ) {
        mainQueue.async {
            let forRecording = forRecording ?? self.shouldConfigureInputBarForRecording

            switch forRecording {
            case true:
                if !forceUpdate {
                    guard !self.inputBar.sendButton.isRecordButton else { return }
                }

                self.inputBar.sendButton.tag = self.coreUI.semTag(for: Strings.recordButtonSemanticTag)

                UIView.transition(
                    with: self.inputBar.sendButton,
                    duration: Floats.inputBarTransitionAnimationDuration,
                    options: [.transitionCrossDissolve]
                ) {
                    self.inputBar.contentView.layer.borderColor = UIColor(Colors.inputBarContentViewRecordLayerBorder).cgColor
                    self.inputBar.inputTextView.layer.borderColor = UIColor(Colors.inputBarInputTextViewRecordLayerBorder).cgColor

                    self.inputBar.sendButton.setImage(
                        self.inputBarConfigService.sendButtonImage(
                            forRecording: forRecording,
                            isHighlighted: false
                        ),
                        for: .normal
                    )
                    self.inputBar.sendButton.setImage(
                        self.inputBarConfigService.sendButtonImage(
                            forRecording: forRecording,
                            isHighlighted: true
                        ),
                        for: .highlighted
                    )

                    self.inputBar.sendButton.isEnabled = self.shouldEnableSendButton
                    self.inputBar.sendButton.tintColor = UIColor(Colors.inputBarSendButtonRecordTint)
                } completion: { _ in
                    self.chatPageViewService.gestureRecognizer?.configureInputBarGestureRecognizers()
                }

            case false:
                if !forceUpdate {
                    guard self.inputBar.sendButton.isRecordButton else { return }
                }

                self.inputBar.sendButton.tag = self.coreUI.semTag(for: Strings.sendButtonSemanticTag)
                self.chatPageViewService.gestureRecognizer?.removeInputBarGestureRecognizers()

                UIView.transition(
                    with: self.inputBar.sendButton,
                    duration: Floats.inputBarTransitionAnimationDuration,
                    options: [.transitionCrossDissolve]
                ) {
                    self.inputBar.contentView.layer.borderColor = UIColor(Colors.inputBarContentViewTextLayerBorder).cgColor
                    self.inputBar.inputTextView.layer.borderColor = UIColor(Colors.inputBarInputTextViewTextLayerBorder).cgColor

                    self.inputBar.sendButton.setImage(
                        self.inputBarConfigService.sendButtonImage(
                            forRecording: forRecording,
                            isHighlighted: false
                        ),
                        for: .normal
                    )
                    self.inputBar.sendButton.setImage(
                        self.inputBarConfigService.sendButtonImage(
                            forRecording: forRecording,
                            isHighlighted: true
                        ),
                        for: .highlighted
                    )

                    self.inputBar.sendButton.isEnabled = self.shouldEnableSendButton
                    self.inputBar.sendButton.tintColor = .accent
                }
            }
        }
    }

    // MARK: - Did Press Record Button

    public func didPressRecordButton(with command: RecordButtonCommand) async -> Exception? {
        switch command {
        case .cancelRecording:
            guard !isStoppingRecording,
                  audioService.recording.isRecording else { return nil }
            isStoppingRecording = true

            defer { isStoppingRecording = false }
            await chatPageViewService.recordingUI?.hideRecordingUI()
            if let exception = audioService.recording.cancelRecording() {
                guard !exception.isEqual(toAny: [.couldntRemoveInput, .noAudioRecorderToStop]) else { return nil }
                return exception
            }

            return nil

        case .startRecording:
            guard !audioService.recording.isRecording else { return nil }
            await chatPageViewService.recordingUI?.showRecordingUI()
            return audioService.recording.startRecording()

        case .stopRecording:
            guard !isStoppingRecording,
                  audioService.recording.isRecording else { return nil }
            isStoppingRecording = true

            defer { isStoppingRecording = false }
            await chatPageViewService.recordingUI?.hideRecordingUI()
            let stopRecordingResult = audioService.recording.stopRecording()

            switch stopRecordingResult {
            case let .success(url):
                guard let inputFile = AudioFile(url) else {
                    return .init(
                        "Failed to generate input audio file.",
                        metadata: [self, #file, #function, #line]
                    )
                }

                return await sendAudioMessage(inputFile)

            case let .failure(exception):
                guard !exception.isEqual(toAny: [.noAudioRecorderToStop, .transcribeNoSuchFileOrDirectory]) else { return nil }
                return exception
            }
        }
    }

    // MARK: - Did Press Send Button

    public func didPressSendButton(with text: String) async -> Exception? {
        guard let conversation = await viewController.currentConversation,
              let users = conversation.users,
              !text.isBlank else { return nil }

        addMockMessageToCurrentConversation(text)

        toggleSendingUI(on: true)
        chatPageViewService.deliveryProgression?.startAnimatingDeliveryProgress()

        let sendTextMessageResult = await clientSession.message.sendTextMessage(
            text,
            toUsers: users,
            inConversation: conversation
        )

        configureInputBar(forceUpdate: true)
        toggleSendingUI(on: false)
        chatPageViewService.deliveryProgression?.stopAnimatingDeliveryProgress()

        switch sendTextMessageResult {
        case let .success(conversation):
            clientSession.conversation.setCurrentConversation(conversation)
            chatPageViewService.reloadCollectionView()
            return nil

        case let .failure(exception):
            return exception
        }
    }

    // MARK: - Text View Did Change

    public func textViewDidChange(to text: String) async -> Exception? {
        guard !isUpdatingIsTypingForCurrentUser else { return nil }
        isUpdatingIsTypingForCurrentUser = true

        defer { isUpdatingIsTypingForCurrentUser = false }
        if let exception = await updateIsTypingForCurrentUser(!text.isBlank) {
            return exception
        }

        return nil
    }

    // MARK: - Auxiliary

    private func addMockMessageToCurrentConversation(_ text: String) {
        guard let conversation = viewController.currentConversation,
              var messages = conversation.messages,
              let currentUser = clientSession.user.currentUser else { return }

        messages.append(.init(
            UserContentConstants.newMessageID,
            fromAccountID: currentUser.id,
            hasAudioComponent: false,
            audioComponents: nil,
            translations: [.init(input: .init(text), output: text, languagePair: .system)],
            readDate: nil,
            sentDate: Date()
        ))

        let newConversation: Conversation = .init(
            conversation.id,
            messageIDs: conversation.messageIDs,
            messages: messages,
            lastModifiedDate: conversation.lastModifiedDate,
            participants: conversation.participants,
            users: conversation.users
        )

        clientSession.conversation.setCurrentConversation(newConversation)
        chatPageViewService.reloadCollectionView()
    }

    private func sendAudioMessage(_ inputFile: AudioFile) async -> Exception? {
        guard let conversation = await viewController.currentConversation,
              let users = conversation.users else { return nil }

        // TODO: Support mock audio messages.
//        addMockMessageToCurrentConversation(text)

        toggleSendingUI(on: true)

        let sendAudioMessageResult = await clientSession.message.sendAudioMessage(
            inputFile,
            toUsers: users,
            inConversation: conversation
        )

        configureInputBar(forceUpdate: true)
        toggleSendingUI(on: false)

        switch sendAudioMessageResult {
        case let .success(conversation):
            chatPageViewService.deliveryProgression?.stopAnimatingDeliveryProgress()

            clientSession.conversation.setCurrentConversation(conversation)
            chatPageViewService.reloadCollectionView()
            return nil

        case let .failure(exception):
            return exception
        }
    }

    private func toggleSendingUI(on: Bool) {
        Task { @MainActor in
            if on {
                inputBar.inputTextView.text = ""
                inputBar.sendButton.startAnimating()
            } else {
                inputBar.sendButton.stopAnimating()
            }

            inputBar.inputTextView.tintColor = on ? UIColor(Colors.inputBarInputTextViewTint) : .accent
            inputBar.sendButton.isUserInteractionEnabled = on ? false : true
        }
    }

    private func updateIsTypingForCurrentUser(_ isTyping: Bool) async -> Exception? {
        @Persistent(.currentUserID) var currentUserID: String?

        guard let conversation = await viewController.currentConversation,
              conversation.participants.count == 2 else { return nil }

        guard let currentUserParticipant = conversation.participants.first(where: { $0.userID == currentUserID }) else {
            return .init(
                "Failed to find current user in conversation participants.",
                metadata: [self, #file, #function, #line]
            )
        }

        guard isTyping != currentUserParticipant.isTyping else { return nil }

        var newParticipants = conversation.participants.filter { $0 != currentUserParticipant }
        newParticipants.append(.init(
            userID: currentUserParticipant.userID,
            hasDeletedConversation: currentUserParticipant.hasDeletedConversation,
            isTyping: isTyping
        ))

        clientSession.user.stopObservingCurrentUserChanges()
        let updateValueResult = await conversation.updateValue(newParticipants, forKey: .participants)
        clientSession.user.startObservingCurrentUserChanges()

        switch updateValueResult {
        case let .success(conversation):
            clientSession.conversation.setCurrentConversation(conversation)
            return nil

        case let .failure(exception):
            return exception
        }
    }
}
