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

public final class InputBarGestureRecognizerService {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.InputBarGestureRecognizer
    private typealias Strings = AppConstants.Strings.ChatPageViewService.InputBarGestureRecognizer

    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.clientSession.user.currentUser) private var currentUser: User?
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    private let viewController: ChatPageViewController

    // MARK: - Computed Properties

    private var inputBar: InputBarAccessoryView { viewController.messageInputBar }

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Public

    public func configureGestureRecognizers() {
        removeInputBarGestureRecognizers()

        guard let currentUser,
              inputBar.sendButton.isRecordButton else { return }

        guard currentUser.canSendAudioMessages else {
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

    public func removeInputBarGestureRecognizers() {
        inputBar.sendButton.gestureRecognizers?.removeAll()
    }

    // MARK: - Gesture Recognizer Selectors

    @objc
    private func longPressGestureRecognized(recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            Task { @MainActor in
                guard let exception = await chatPageViewService.inputBar?.didPressRecordButton(with: .startRecording) else { return }
                showError(exception)
            }

        case .changed:
            let convertedPoint = viewController.view.convert(
                recognizer.location(in: viewController.view),
                to: inputBar.sendButton
            )

            Task { @MainActor in
                guard !inputBar.sendButton.bounds.contains(convertedPoint),
                      services.audio.recording.isInOrWillTransitionToRecordingState,
                      let exception = await chatPageViewService.inputBar?.didPressRecordButton(with: .cancelRecording) else { return }
                showError(exception)
            }

        case .ended:
            /// - NOTE: Fixes a bug in which an immediate release of the button would fail to stop recording.
            @Sendable
            func doubleCheckState() {
                core.gcd.after(.milliseconds(Floats.millisecondsDelay)) {
                    Task { @MainActor in
                        guard self.services.audio.recording.isInOrWillTransitionToRecordingState else { return }
                        Logger.log(
                            "Intercepted failure to stop recording bug.",
                            domain: .bugPrevention,
                            metadata: [self, #file, #function, #line]
                        )
                        guard let exception = await self.chatPageViewService.inputBar?.didPressRecordButton(with: .stopRecording) else { return }
                        self.showError(exception)
                    }
                }
            }

            Task { @MainActor in
                if let exception = await chatPageViewService.inputBar?.didPressRecordButton(with: .stopRecording) {
                    showError(exception)
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
            ).present()

            let isKeyboardFirstResponder = inputBar.inputTextView.isFirstResponder

            services.audio.acknowledgedAudioMessagesUnsupported = true
            chatPageViewService.inputBar?.configureInputBar(forRecording: false)

            core.gcd.after(.milliseconds(Floats.millisecondsDelay)) {
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
                let requestPermissionResult = await services.permission.requestPermission(for: type)

                switch requestPermissionResult {
                case let .success(status):
                    defer { configureGestureRecognizers() }

                    guard status == .granted else {
                        _ = await services.permission.presentCTA(for: type)
                        return
                    }

                case let .failure(exception):
                    Logger.log(exception, with: .toast())
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
        guard exception.isEqual(toAny: [
            .avFoundationError,
            .kAFAssistantError,
            .noSpeechDetected,
            .transcribeNoSuchFileOrDirectory,
        ]) else {
            Logger.log(exception, with: .toast())
            return
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
