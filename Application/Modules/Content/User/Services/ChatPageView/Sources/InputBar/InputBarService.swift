//
//  InputBarService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import AVFAudio
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import InputBarAccessoryView

public final class InputBarService {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case shouldConfigureInputBarForRecording
    }

    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatPageViewService.InputBar
    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.InputBar
    private typealias Strings = AppConstants.Strings.ChatPageViewService.InputBar

    // MARK: - Dependencies

    @Dependency(\.avSpeechSynthesizer) private var avSpeechSynthesizer: AVSpeechSynthesizer
    @Dependency(\.build) private var build: Build
    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.inputBarConfigService) private var inputBarConfigService: InputBarConfigService
    @Dependency(\.mainQueue) private var mainQueue: DispatchQueue
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    public private(set) var isForcingAppearance = false

    private let viewController: ChatPageViewController

    // swiftlint:disable:next identifier_name
    @Cached(CacheKey.shouldConfigureInputBarForRecording) private var cachedShouldConfigureInputBarForRecording: (
        encodedConversationID: String,
        shouldConfigureForRecording: Bool
    )?
    private var isStoppingRecording = false

    // MARK: - Computed Properties

    public var isFirstResponder: Bool { inputBar.inputTextView.isFirstResponder }
    public var shouldEnableAttachMediaButton: Bool {
        guard build.isOnline else { return false }

        let isConversationEmpty = viewController.currentConversation?.isEmpty ?? true
        let isRecipientBarFirstResponder = chatPageViewService.recipientBar?.layout.textField?.isFirstResponder ?? false
        let isSendingMessage = messageDeliveryService.isSendingMessage

        return !isConversationEmpty && !isRecipientBarFirstResponder && !isSendingMessage
    }

    public var shouldEnableSendButton: Bool {
        guard build.isOnline else { return false }

        let isConversationEmpty = viewController.currentConversation?.isEmpty ?? true
        let isRecipientBarFirstResponder = chatPageViewService.recipientBar?.layout.textField?.isFirstResponder ?? false
        let isSendButtonConfiguredForText = !inputBar.sendButton.isRecordButton
        let isSendingMessage = messageDeliveryService.isSendingMessage
        let isTextViewTextBlank = inputBar.inputTextView.text.sanitized.isBlank

        guard isSendButtonConfiguredForText else { return !isConversationEmpty && !isRecipientBarFirstResponder && !isSendingMessage }
        return !isConversationEmpty && !isRecipientBarFirstResponder && !isSendingMessage && !isTextViewTextBlank
    }

    private var inputBar: InputBarAccessoryView { viewController.messageInputBar }
    private var shouldConfigureInputBarForRecording: Bool {
        let isTextViewTextBlank = inputBar.inputTextView.text.sanitized.isBlank
        if !isTextViewTextBlank,
           let cachedValue = cachedShouldConfigureInputBarForRecording,
           cachedValue.encodedConversationID == viewController.currentConversation?.id.encoded {
            return cachedValue.shouldConfigureForRecording
        }

        let canConfigureInputBarForRecording = inputBarConfigService.canConfigureInputBarForRecording
        let shouldConfigureForRecording = canConfigureInputBarForRecording && isTextViewTextBlank

        guard !isTextViewTextBlank else { return shouldConfigureForRecording }
        cachedShouldConfigureInputBarForRecording = (
            viewController.currentConversation?.id.encoded ?? .bangQualifiedEmpty,
            shouldConfigureForRecording
        )

        return shouldConfigureForRecording
    }

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
            if !forceUpdate {
                switch forRecording {
                case true:
                    guard !self.inputBar.sendButton.isRecordButton else { return }

                case false:
                    guard self.inputBar.sendButton.isRecordButton else {
                        self.inputBar.leftStackView.attachMediaButton?.isEnabled = self.shouldEnableAttachMediaButton
                        self.inputBar.sendButton.isEnabled = self.shouldEnableSendButton
                        return
                    }
                }
            }

            self.inputBar.sendButton.centerYAnchor.constraint(
                equalTo: self.inputBar.contentView.centerYAnchor,
                constant: 0
            ).isActive = true

            self.inputBar.sendButton.trailingAnchor.constraint(
                equalTo: self.inputBar.contentView.trailingAnchor,
                constant: -(self.inputBar.sendButton.frame.width - Floats.sendButtonTrailingAnchorConstraintConstantDecrement)
            ).isActive = true

            switch forRecording {
            case true:
                self.inputBar.sendButton.tag = self.core.ui.semTag(for: Strings.recordButtonSemanticTag)

                UIView.transition(
                    with: self.inputBar.sendButton,
                    duration: Floats.transitionAnimationDuration,
                    options: [.transitionCrossDissolve]
                ) {
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

                    self.inputBar.leftStackView.attachMediaButton?.isEnabled = self.shouldEnableAttachMediaButton
                    self.inputBar.sendButton.isEnabled = self.shouldEnableSendButton

                    self.inputBar.sendButton.tintColor = UIColor(Colors.sendButtonRecordTint)
                    self.inputBar.sendButton.alpha = 1
                } completion: { _ in
                    self.chatPageViewService.inputBarGestureRecognizer?.configureGestureRecognizers()
                }

            case false:
                self.inputBar.sendButton.tag = self.core.ui.semTag(for: Strings.sendButtonSemanticTag)
                self.chatPageViewService.inputBarGestureRecognizer?.removeInputBarGestureRecognizers()

                UIView.transition(
                    with: self.inputBar.sendButton,
                    duration: Floats.transitionAnimationDuration,
                    options: [.transitionCrossDissolve]
                ) {
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

                    self.inputBar.leftStackView.attachMediaButton?.isEnabled = self.shouldEnableAttachMediaButton
                    self.inputBar.sendButton.isEnabled = self.shouldEnableSendButton

                    self.inputBar.sendButton.tintColor = .accent
                    self.inputBar.sendButton.alpha = 1
                }
            }
        }
    }

    // MARK: - Become First Responder

    public func becomeFirstResponder() {
        let startDate = Date.now
        while chatPageState.isPresented,
              !inputBar.inputTextView.isFirstResponder,
              abs(startDate.seconds(from: .now)) < 5 {
            guard inputBar.inputTextView.canBecomeFirstResponder else { break }
            inputBar.inputTextView.becomeFirstResponder()
        }
    }

    // MARK: - Did Press Attach Media Button

    public func didPressAttachMediaButton() {
        chatPageViewService.mediaActionHandler?.attachMediaButtonTapped()
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

    @MainActor
    public func didPressSendButton(with text: String) async -> Exception? {
        /// - NOTE: Fixes a bug in which rapid typing would cause the send button to mistakenly become enabled.
        var isConversationEmpty: Bool {
            if let currentConversation = viewController.currentConversation,
               currentConversation.isEmpty {
                Logger.log(
                    "Intercepted invalid send button press bug.",
                    domain: .bugPrevention,
                    metadata: [self, #file, #function, #line]
                )

                return true
            }

            return false
        }

        guard !isConversationEmpty else { return nil }
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
            let startDate = Date.now
            while self.chatPageState.isPresented,
                  !textField.isFirstResponder,
                  abs(startDate.seconds(from: .now)) < 5 {
                textField.becomeFirstResponder()
            }
            self.viewController.view.isUserInteractionEnabled = true
            self.isForcingAppearance = false
        }
    }

    // MARK: - Set Attach Media Button Image

    public func setAttachMediaButtonImage() {
        let attachMediaButtonNormalImage = inputBarConfigService.attachMediaButtonImage(isHighlighted: false)
        let attachMediaButtonHighlightedImage = inputBarConfigService.attachMediaButtonImage(isHighlighted: true)

        inputBar.leftStackView.attachMediaButton?.setImage(attachMediaButtonNormalImage, for: .normal)
        inputBar.leftStackView.attachMediaButton?.setImage(attachMediaButtonHighlightedImage, for: .highlighted)
    }

    // MARK: - Set Attach Media Button Is Enabled

    public func setAttachMediaButtonIsEnabled(_ isEnabled: Bool) {
        mainQueue.async {
            if !self.isForcingAppearance {
                guard self.inputBar.leftStackView.attachMediaButton?.isEnabled != isEnabled else { return }
            }

            guard let attachMediaButton = self.inputBar.leftStackView.attachMediaButton else { return }

            UIView.transition(
                with: attachMediaButton,
                duration: Floats.transitionAnimationDuration,
                options: [.transitionCrossDissolve]
            ) {
                attachMediaButton.isEnabled = isEnabled
            }
        }
    }

    // MARK: - Set Send Button Is Enabled

    public func setSendButtonIsEnabled(_ isEnabled: Bool) {
        mainQueue.async {
            if !self.isForcingAppearance {
                guard self.inputBar.sendButton.isEnabled != isEnabled else { return }
            }

            UIView.transition(
                with: self.inputBar.sendButton,
                duration: Floats.transitionAnimationDuration,
                options: [.transitionCrossDissolve]
            ) {
                self.inputBar.sendButton.isEnabled = isEnabled
            }
        }
    }

    // MARK: - Toggle Sending UI

    public func toggleSendingUI(
        on: Bool,
        clearInputTextViewText: Bool = true
    ) {
        mainQueue.async {
            if on {
                defer {
                    self.inputBar.sendButton.startAnimating()
                    self.setAttachMediaButtonIsEnabled(false)
                }

                guard clearInputTextViewText else { return }
                self.inputBar.inputTextView.text = ""
            } else {
                self.inputBar.sendButton.stopAnimating()
                self.setAttachMediaButtonIsEnabled(self.shouldEnableAttachMediaButton)
            }

            self.inputBar.inputTextView.tintColor = on ? UIColor(Colors.inputTextViewTint) : .accent
            self.inputBar.leftStackView.attachMediaButton?.isUserInteractionEnabled = !on
            self.inputBar.sendButton.isUserInteractionEnabled = !on
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
}

// swiftlint:enable file_length type_body_length
