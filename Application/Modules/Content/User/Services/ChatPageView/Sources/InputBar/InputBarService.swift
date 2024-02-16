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
import InputBarAccessoryView
import Redux

public final class InputBarService {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatPageViewService.InputBar
    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.InputBar
    private typealias Strings = AppConstants.Strings.ChatPageViewService.InputBar

    // MARK: - Dependencies

    @Dependency(\.avSpeechSynthesizer) private var avSpeechSynthesizer: AVSpeechSynthesizer
    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.inputBarConfigService) private var inputBarConfigService: InputBarConfigService
    @Dependency(\.mainQueue) private var mainQueue: DispatchQueue
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    private let viewController: ChatPageViewController

    private var isStoppingRecording = false
    private var isUpdatingIsTypingForCurrentUser = false

    // MARK: - Computed Properties

    public var shouldEnableSendButton: Bool {
        let isConversationEmpty = viewController.currentConversation?.isEmpty ?? true
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

    // MARK: - Did Press Record Button

    public func didPressRecordButton(with command: RecordButtonCommand) async -> Exception? {
        switch command {
        case .cancelRecording:
            guard !isStoppingRecording,
                  services.audio.recording.isInOrWillTransitionToRecordingState else { return nil }
            isStoppingRecording = true

            defer { isStoppingRecording = false }
            await chatPageViewService.recordingUI?.hideRecordingUI()
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
            services.haptics.generateFeedback(.medium)
            return services.audio.recording.startRecording()

        case .stopRecording:
            guard !isStoppingRecording,
                  services.audio.recording.isInOrWillTransitionToRecordingState else { return nil }
            isStoppingRecording = true

            defer { isStoppingRecording = false }
            await chatPageViewService.recordingUI?.hideRecordingUI()
            let stopRecordingResult = services.audio.recording.stopRecording()

            switch stopRecordingResult {
            case let .success(url):
                guard let inputFile = AudioFile(url) else {
                    return .init(
                        "Failed to generate input audio file.",
                        metadata: [self, #file, #function, #line]
                    )
                }

                return await chatPageViewService.messageDelivery?.sendAudioMessage(inputFile)

            case let .failure(exception):
                guard !exception.isEqual(toAny: [.noAudioRecorderToStop, .transcribeNoSuchFileOrDirectory]) else { return nil }
                playRecordingCancellationVibration()
                return exception
            }
        }
    }

    // MARK: - Did Press Send Button

    public func didPressSendButton(with text: String) async -> Exception? {
        avSpeechSynthesizer.stopSpeaking(at: .immediate)
        return await chatPageViewService.messageDelivery?.sendTextMessage(text)
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
