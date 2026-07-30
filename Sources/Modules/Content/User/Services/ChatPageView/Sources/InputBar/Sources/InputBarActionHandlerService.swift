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

@MainActor
final class InputBarActionHandlerService {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.InputBar

    // MARK: - Dependencies

    @Dependency(\.avSpeechSynthesizer) private var avSpeechSynthesizer: AVSpeechSynthesizer
    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    private let viewController: ChatPageViewController

    private var isStoppingRecording = false
    private var liveTranscriptionSession: LiveTranscriptionSession?

    // MARK: - Computed Properties

    private var inputBar: InputBarAccessoryView {
        viewController.messageInputBar
    }

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
            do throws(Exception) {
                try await services
                    .messageRecipientConsent
                    .sendConsentMessageInCurrentConversation()
            } catch {
                Logger.log(
                    error,
                    with: .toast
                )
            }
        }
    }

    // MARK: - Did Press Record Button

    func didPressRecordButton(
        with command: RecordButtonCommand
    ) async throws(Exception) {
        switch command {
        case .cancelRecording:
            guard !isStoppingRecording,
                  services.audio.recording.isInOrWillTransitionToRecordingState else { return }
            isStoppingRecording = true

            defer { isStoppingRecording = false }
            liveTranscriptionSession?.cancel()
            liveTranscriptionSession = nil

            await chatPageViewService.recordingUI?.hideRecordingUI()
            chatPageViewService.recipientBar?.layout.setIsUserInteractionEnabled(true)

            do {
                try services.audio.recording.cancelRecording()
            } catch {
                guard !error.isEqual(toAny: [
                    .couldntRemoveInput,
                    .noAudioRecorderToStop,
                ]) else { return }
                throw error
            }

            playRecordingCancellationVibration()

        case .startRecording:
            guard !services.audio.recording.isInOrWillTransitionToRecordingState else { return }
            avSpeechSynthesizer.stopSpeakingIfNeeded()

            chatPageViewService.audioMessagePlayback?.stopPlayback()
            await chatPageViewService.recordingUI?.showRecordingUI()
            chatPageViewService.recipientBar?.layout.setIsUserInteractionEnabled(false)
            services.haptics.generateFeedback(.medium)

            if let languageCode = clientSession.entity.user.currentUser?.languageCode {
                liveTranscriptionSession = services.audio.transcription.startLiveSession(
                    languageCode: languageCode
                )
            }

            let liveTranscriptionSession = liveTranscriptionSession
            try services.audio.recording.startRecording { liveTranscriptionSession?.append($0) }

        case .stopRecording:
            guard !isStoppingRecording,
                  services.audio.recording.isInOrWillTransitionToRecordingState else { return }
            isStoppingRecording = true

            defer { isStoppingRecording = false }
            await chatPageViewService.recordingUI?.hideRecordingUI()
            chatPageViewService.recipientBar?.layout.setIsUserInteractionEnabled(true)

            do throws(Exception) {
                let url = try services.audio.recording.stopRecording()
                let transcription = await liveTranscriptionSession?.finish()
                liveTranscriptionSession = nil

                guard let inputFile = AudioFile(url) else {
                    throw Exception(
                        "Failed to generate input audio file.",
                        metadata: .init(sender: self)
                    )
                }

                try await messageDeliveryService.sendAudioMessage(
                    inputFile,
                    transcription: transcription
                )
            } catch {
                liveTranscriptionSession?.cancel()
                liveTranscriptionSession = nil
                guard !error.isEqual(toAny: [
                    .noAudioRecorderToStop,
                    .transcribeNoSuchFileOrDirectory,
                ]) else { return }
                playRecordingCancellationVibration()
                throw error
            }
        }
    }

    // MARK: - Did Press Send Button

    @MainActor
    func didPressSendButton(with text: String) async throws(Exception) {
        // - NOTE: Fixes a bug in which rapid typing would cause the send button to mistakenly become enabled.
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

        guard !isConversationEmpty else { return }
        avSpeechSynthesizer.stopSpeakingIfNeeded()
        try await messageDeliveryService.sendTextMessage(text)
    }

    // MARK: - Auxiliary

    private func playRecordingCancellationVibration() {
        services.haptics.generateFeedback(.heavy)
        Task.delayed(by: .milliseconds(Floats.recordingCancellationVibrationDelayMilliseconds)) { @MainActor in
            self.services.haptics.generateFeedback(.heavy)
            Task.delayed(by: .milliseconds(Floats.recordingCancellationVibrationDelayMilliseconds)) { @MainActor in
                self.services.haptics.generateFeedback(.heavy)
            }
        }
    }
}
