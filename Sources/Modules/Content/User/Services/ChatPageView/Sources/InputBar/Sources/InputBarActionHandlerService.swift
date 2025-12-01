//
//  InputBarActionHandlerService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/04/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import AVFAudio
import Foundation

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import InputBarAccessoryView

final class InputBarActionHandlerService {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.InputBar

    // MARK: - Dependencies

    @Dependency(\.avSpeechSynthesizer) private var avSpeechSynthesizer: AVSpeechSynthesizer
    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    private let viewController: ChatPageViewController

    private var isStoppingRecording = false

    // MARK: - Computed Properties

    private var inputBar: InputBarAccessoryView { viewController.messageInputBar }

    // MARK: - Init

    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Did Press Attach Media Button

    func didPressAttachMediaButton() {
        chatPageViewService.mediaActionHandler?.attachMediaButtonTapped()
    }

    // MARK: - Did Press Consent Button

    @objc
    func didPressConsentButton() {
        Task {
            if let exception = await services.messageRecipientConsent.sendConsentMessageInCurrentConversation() {
                Logger.log(exception, with: .toast)
            }
        }
    }

    // MARK: - Did Press Record Button

    func didPressRecordButton(with command: RecordButtonCommand) async -> Exception? {
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
                        metadata: .init(sender: self)
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
    func didPressSendButton(with text: String) async -> Exception? {
        /// - NOTE: Fixes a bug in which rapid typing would cause the send button to mistakenly become enabled.
        var isConversationEmpty: Bool {
            if let currentConversation = viewController.currentConversation,
               currentConversation.isEmpty {
                Logger.log(
                    "Intercepted invalid send button press bug.",
                    domain: .bugPrevention,
                    sender: self
                )

                return true
            }

            return false
        }

        guard !isConversationEmpty else { return nil }
        avSpeechSynthesizer.stopSpeaking(at: .immediate)
        return await messageDeliveryService.sendTextMessage(text)
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
