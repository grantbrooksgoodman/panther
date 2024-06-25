//
//  InputBarService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import AVFAudio
import Foundation
import UIKit

/* 3rd-party */
import CoreArchitecture
import InputBarAccessoryView

// swiftlint:disable:next type_body_length
public final class InputBarService {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatPageViewService.InputBar
    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.InputBar
    private typealias Strings = AppConstants.Strings.ChatPageViewService.InputBar

    // MARK: - Dependencies

    @Dependency(\.avSpeechSynthesizer) private var avSpeechSynthesizer: AVSpeechSynthesizer
    @Dependency(\.build) private var build: Build
    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.inputBarConfigService) private var inputBarConfigService: InputBarConfigService
    @Dependency(\.mainQueue) private var mainQueue: DispatchQueue
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    public private(set) var isForcingAppearance = false

    private let viewController: ChatPageViewController

    private var isStoppingRecording = false
    private var isUpdatingIsTypingForCurrentUser = false

    // MARK: - Computed Properties

    public var isFirstResponder: Bool { inputBar.inputTextView.isFirstResponder }
    public var shouldEnableSendButton: Bool {
        guard build.isOnline else { return false }

        let isConversationEmpty = viewController.currentConversation?.isEmpty ?? true
        let isRecipientBarFirstResponder = chatPageViewService.recipientBar?.layout.textField?.isFirstResponder ?? false
        let isSendButtonConfiguredForText = !inputBar.sendButton.isRecordButton
        let isTextViewTextBlank = inputBar.inputTextView.text.sanitized.isBlank

        guard isSendButtonConfiguredForText else { return !isConversationEmpty && !isRecipientBarFirstResponder }
        return !isConversationEmpty && !isRecipientBarFirstResponder && !isTextViewTextBlank
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

                self.inputBar.sendButton.tag = self.core.ui.semTag(for: Strings.recordButtonSemanticTag)

                UIView.transition(
                    with: self.inputBar.sendButton,
                    duration: Floats.transitionAnimationDuration,
                    options: [.transitionCrossDissolve]
                ) {
                    self.inputBar.contentView.layer.borderColor = UIColor(Colors.contentViewRecordLayerBorder).cgColor
                    self.inputBar.inputTextView.layer.borderColor = UIColor(Colors.inputTextViewRecordLayerBorder).cgColor

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
                    self.inputBar.sendButton.tintColor = UIColor(Colors.sendButtonRecordTint)
                } completion: { _ in
                    self.chatPageViewService.inputBarGestureRecognizer?.configureInputBarGestureRecognizers()
                }

            case false:
                if !forceUpdate {
                    guard self.inputBar.sendButton.isRecordButton else {
                        self.inputBar.sendButton.isEnabled = self.shouldEnableSendButton
                        return
                    }
                }

                self.inputBar.sendButton.tag = self.core.ui.semTag(for: Strings.sendButtonSemanticTag)
                self.chatPageViewService.inputBarGestureRecognizer?.removeInputBarGestureRecognizers()

                UIView.transition(
                    with: self.inputBar.sendButton,
                    duration: Floats.transitionAnimationDuration,
                    options: [.transitionCrossDissolve]
                ) {
                    self.inputBar.contentView.layer.borderColor = UIColor(Colors.contentViewTextLayerBorder).cgColor
                    self.inputBar.inputTextView.layer.borderColor = UIColor(Colors.inputTextViewTextLayerBorder).cgColor

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

    // MARK: - Become First Responder

    public func becomeFirstResponder() {
        guard chatPageState.isPresented else { return }
        while !inputBar.inputTextView.isFirstResponder {
            guard chatPageState.isPresented,
                  inputBar.inputTextView.canBecomeFirstResponder else { break }
            inputBar.inputTextView.becomeFirstResponder()
        }
    }

    // MARK: - Did Press Record Button

    public func didPressRecordButton(with command: RecordButtonCommand) async -> Exception? {
        switch command {
        case .cancelRecording:
            guard !isStoppingRecording,
                  services.audio.recording.isInOrWillTransitionToRecordingState else { return nil }
            isStoppingRecording = true

            defer { isStoppingRecording = false }
            await chatPageViewService.recordingUI?.hideRecordingUI()
            chatPageViewService.recipientBar?.layout.setIsUserInteractionEnabled(true)
            if let exception = services.audio.recording.cancelRecording() {
                guard !exception.isEqual(toAny: [.couldntRemoveInput, .noAudioRecorderToStop]) else { return nil }
                return exception
            }

            playRecordingCancellationVibration()
            return nil

        case .startRecording:
            guard !services.audio.recording.isInOrWillTransitionToRecordingState else { return nil }
            avSpeechSynthesizer.stopSpeaking(at: .immediate)
            chatPageViewService.audioMessagePlayback?.stopPlayback()
            await chatPageViewService.recordingUI?.showRecordingUI()
            chatPageViewService.recipientBar?.layout.setIsUserInteractionEnabled(false)
            services.haptics.generateFeedback(.medium)
            return services.audio.recording.startRecording()

        case .stopRecording:
            guard !isStoppingRecording,
                  services.audio.recording.isInOrWillTransitionToRecordingState else { return nil }
            isStoppingRecording = true

            defer { isStoppingRecording = false }
            await chatPageViewService.recordingUI?.hideRecordingUI()
            chatPageViewService.recipientBar?.layout.setIsUserInteractionEnabled(true)
            let stopRecordingResult = services.audio.recording.stopRecording()

            switch stopRecordingResult {
            case let .success(url):
                guard let inputFile = AudioFile(url) else {
                    return .init(
                        "Failed to generate input audio file.",
                        metadata: [self, #file, #function, #line]
                    )
                }

                return await messageDeliveryService.sendAudioMessage(inputFile)

            case let .failure(exception):
                guard !exception.isEqual(toAny: [.noAudioRecorderToStop, .transcribeNoSuchFileOrDirectory]) else { return nil }
                playRecordingCancellationVibration()
                return exception
            }
        }
    }

    // MARK: - Did Press Send Button

    public func didPressSendButton(with text: String) async -> Exception? {
        if let currentConversation = await viewController.currentConversation {
            guard !currentConversation.isEmpty else {
                Logger.log(
                    "Intercepted invalid send button press bug.",
                    domain: .bugPrevention,
                    metadata: [self, #file, #function, #line]
                )
                return nil
            }
        }

        avSpeechSynthesizer.stopSpeaking(at: .immediate)
        return await messageDeliveryService.sendTextMessage(text)
    }

    // MARK: - Force Appearance

    /// - NOTE: Fixes a bug in which the dismissal of the contact selector sheet would cause the input bar to hide.
    public func forceAppearance() {
        guard let textField = chatPageViewService.recipientBar?.layout.textField else { return }

        viewController.view.isUserInteractionEnabled = false
        isForcingAppearance = true

        Logger.log(
            "Intercepted input bar disappearance bug.",
            domain: .bugPrevention,
            metadata: [self, #file, #function, #line]
        )

        becomeFirstResponder()
        core.gcd.after(.milliseconds(Floats.forceAppearanceDelayMilliseconds)) {
            while !textField.isFirstResponder { textField.becomeFirstResponder() }
            self.viewController.view.isUserInteractionEnabled = true
            self.isForcingAppearance = false
        }
    }

    // MARK: - Set Send Button Is Enabled

    public func setSendButtonIsEnabled(_ sendButtonIsEnabled: Bool) {
        if !isForcingAppearance {
            guard inputBar.sendButton.isEnabled != sendButtonIsEnabled else { return }
        }

        mainQueue.async {
            UIView.transition(
                with: self.inputBar.sendButton,
                duration: Floats.transitionAnimationDuration,
                options: [.transitionCrossDissolve]
            ) {
                self.inputBar.sendButton.isEnabled = sendButtonIsEnabled
            }
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

    // MARK: - Toggle Sending UI

    public func toggleSendingUI(on: Bool) {
        mainQueue.async {
            if on {
                self.inputBar.inputTextView.text = ""
                self.inputBar.sendButton.startAnimating()
            } else {
                self.inputBar.sendButton.stopAnimating()
            }

            self.inputBar.inputTextView.tintColor = on ? UIColor(Colors.inputTextViewTint) : .accent
            self.inputBar.sendButton.isUserInteractionEnabled = on ? false : true
        }
    }

    // MARK: - Auxiliary

    private func playRecordingCancellationVibration() {
        services.haptics.generateFeedback(.heavy)
        core.gcd.after(.milliseconds(Floats.recordingCancellationVibrationDelayMilliseconds)) {
            self.services.haptics.generateFeedback(.heavy)
            self.core.gcd.after(.milliseconds(Floats.recordingCancellationVibrationDelayMilliseconds)) { self.services.haptics.generateFeedback(.heavy) }
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
            guard clientSession.conversation.currentConversation?.id.key == conversation.id.key else { return nil }
            clientSession.conversation.setCurrentConversation(conversation)
            return nil

        case let .failure(exception):
            return exception
        }
    }
}
