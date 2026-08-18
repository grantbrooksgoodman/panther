//
//  InputBarGestureRecognizerService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 03/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem

/* 3rd-party */
import InputBarAccessoryView

/// The service that manages the input bar's gesture recognizers.
///
/// ``InputBarGestureRecognizerService`` installs the recognizers on the send button while it is
/// configured as a record button: a long press that records for its duration, and taps that show
/// recording instructions or – when recording is unavailable – request the necessary permissions
/// or explain why audio messages are unsupported.
@MainActor
final class InputBarGestureRecognizerService {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.InputBarGestureRecognizer
    private typealias Strings = AppConstants.Strings.ChatPageViewService.InputBarGestureRecognizer

    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession.entity.user.currentUser) private var currentUser: User?
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    private let viewController: ChatPageViewController

    // MARK: - Computed Properties

    private var inputBar: InputBarAccessoryView {
        viewController.messageInputBar
    }

    // MARK: - Init

    /// Creates the service, binding it to the given chat page view controller.
    ///
    /// - Parameter viewController: The chat page's messages view controller.
    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Internal

    /// Installs the record button's gesture recognizers for the current state.
    ///
    /// When the current user cannot send audio messages, or has not granted the microphone and
    /// transcription permissions, a tap instead explains the limitation or requests the
    /// permissions. Otherwise, a long press records and a tap shows recording instructions.
    ///
    /// While the transcription support inventory is still loading, audio-message support cannot
    /// yet be determined, so no recognizers are installed.
    ///
    /// This method has no effect while the send button is not configured as a record button.
    func configureGestureRecognizers() {
        removeInputBarGestureRecognizers()

        guard let currentUser,
              inputBar.sendButton.isRecordButton else { return }

        guard currentUser.canSendAudioMessages else {
            // A provisional verdict (inventory still loading) must not wire
            // the unsupported-alert tap, whose acknowledgement permanently
            // hides the record button; the inventory-loaded event re-runs
            // configuration once the verdict is definitive.
            guard services.audio.transcription.isSupportInventoryLoaded else { return }
            inputBar.sendButton.addOrEnable(UITapGestureRecognizer(
                target: self,
                action: #selector(presentAudioMessagesUnsupportedAlert)
            ))
            return
        }

        guard services.permission.recordPermissionStatus == .granted,
              services.permission.transcribePermissionStatus == .granted else {
            inputBar.sendButton.addOrEnable(UITapGestureRecognizer(
                target: self,
                action: #selector(requestPermissions)
            ))
            return
        }

        let longPressGesture: UILongPressGestureRecognizer = .init(target: self, action: #selector(longPressGestureRecognized))
        longPressGesture.minimumPressDuration = Floats.longPressGestureMinimumPressDuration

        inputBar.sendButton.addOrEnable(longPressGesture)
        inputBar.sendButton.addOrEnable(UITapGestureRecognizer(
            target: self,
            action: #selector(showRecordingInstructionToast)
        ))
    }

    /// Removes all of the send button's gesture recognizers.
    func removeInputBarGestureRecognizers() {
        inputBar.sendButton.gestureRecognizers?.removeAll()
    }

    // MARK: - Gesture Recognizer Selectors

    @objc
    private func longPressGestureRecognized(recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            Task { @MainActor in
                do throws(Exception) {
                    try await chatPageViewService
                        .inputBar?
                        .actionHandler
                        .didPressRecordButton(with: .startRecording)
                } catch {
                    showError(error)
                }
            }

        case .changed:
            let convertedPoint = viewController.view.convert(
                recognizer.location(in: viewController.view),
                to: inputBar.sendButton
            )

            Task { @MainActor in
                guard !inputBar.sendButton.bounds.contains(convertedPoint),
                      services.audio.recording.isInOrWillTransitionToRecordingState else { return }
                do throws(Exception) {
                    try await chatPageViewService
                        .inputBar?
                        .actionHandler
                        .didPressRecordButton(with: .cancelRecording)
                } catch {
                    showError(error)
                }
            }

        case .ended:
            /// - NOTE: Fixes a bug in which an immediate release of the button would fail to stop recording.
            func doubleCheckState() {
                Task.delayed(
                    by: .milliseconds(Floats.millisecondsDelay)
                ) { @MainActor in
                    guard self
                        .services
                        .audio
                        .recording
                        .isInOrWillTransitionToRecordingState else { return }

                    Logger.log(
                        "Intercepted failure to stop recording bug.",
                        domain: .bugPrevention,
                        sender: self
                    )

                    do throws(Exception) {
                        try await self
                            .chatPageViewService
                            .inputBar?
                            .actionHandler
                            .didPressRecordButton(with: .stopRecording)
                    } catch {
                        self.showError(error)
                    }
                }
            }

            Task { @MainActor in
                do throws(Exception) {
                    try await chatPageViewService
                        .inputBar?
                        .actionHandler
                        .didPressRecordButton(with: .stopRecording)
                } catch {
                    showError(error)
                }

                doubleCheckState()
            }

        default: ()
        }
    }

    @objc
    private func presentAudioMessagesUnsupportedAlert() {
        Task { @MainActor in
            await AKAlert(
                message: Strings.audioMessagesUnsupportedAlertMessage,
                actions: [.cancelAction(title: Strings.audioMessagesUnsupportedAlertCancelButtonTitle)]
            ).present(translating: [.message])

            let isKeyboardFirstResponder = inputBar.inputTextView.isFirstResponder

            services.audio.acknowledgedAudioMessagesUnsupported = true
            chatPageViewService.inputBar?.configureInputBar(forRecording: false)

            Task.delayed(by: .milliseconds(Floats.millisecondsDelay)) { @MainActor in
                guard isKeyboardFirstResponder else {
                    self.viewController.becomeFirstResponder()
                    return
                }

                self.inputBar.inputTextView.becomeFirstResponder()
            }
        }
    }

    @objc
    private func requestPermissions() {
        func requestPermission(for type: PermissionService.PermissionType) {
            Task { @MainActor in
                do throws(Exception) {
                    let status = try await services.permission.requestPermission(
                        for: type
                    )

                    defer { configureGestureRecognizers() }
                    guard status == .granted else {
                        _ = await services.permission.presentCTA(for: type)
                        return
                    }
                } catch {
                    Logger.log(
                        error,
                        with: .toast
                    )
                }
            }
        }

        guard services.permission.recordPermissionStatus == .granted else {
            requestPermission(for: .recording)
            guard services.permission.transcribePermissionStatus != .granted else { return }
            requestPermission(for: .transcription)
            return
        }

        requestPermission(for: .transcription)
    }

    @objc
    private func showRecordingInstructionToast() {
        Toast.show(.init(
            .banner(style: .info, appearanceEdge: .bottom, showsDismissButton: false),
            message: Localized(.holdDownToRecord).wrappedValue,
            perpetuation: .ephemeral(.seconds(Floats.recordingInstructionToastPerpetuationDuration))
        ))
    }

    // MARK: - Auxiliary

    private func showError(_ exception: Exception) {
        guard exception.isEqual(toAny: AppException.audioRecordingFailures) else {
            return Logger.log(
                exception,
                with: .toast
            )
        }

        guard exception.descriptor == Strings.noSpeechDetectedExceptionDescriptor else {
            Toast.show(.init(
                .banner(style: .error, appearanceEdge: .bottom, showsDismissButton: false),
                message: Localized(.tryAgain).wrappedValue,
                perpetuation: .ephemeral(.seconds(Floats.errorToastPerpetuationDuration))
            ))
            return
        }

        Toast.show(.init(
            .banner(style: .warning, appearanceEdge: .bottom, showsDismissButton: false),
            message: Localized(.noSpeechDetected).wrappedValue,
            perpetuation: .ephemeral(.seconds(Floats.errorToastPerpetuationDuration))
        ))
    }
}
