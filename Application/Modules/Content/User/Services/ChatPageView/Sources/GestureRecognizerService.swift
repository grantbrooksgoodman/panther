//
//  GestureRecognizerService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 03/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import AlertKit
import InputBarAccessoryView
import Redux

public final class GestureRecognizerService {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.GestureRecognizerService
    private typealias Strings = AppConstants.Strings.GestureRecognizerService

    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.coreKit.gcd) private var coreGCD: CoreKit.GCD
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

    public func configureInputBarGestureRecognizers() {
        func addOrEnable(_ gestureRecognizer: UIGestureRecognizer) {
            guard let existingGestureRecognizer = inputBar.sendButton.gestureRecognizers?.first(where: { $0 == gestureRecognizer }) else {
                inputBar.sendButton.addGestureRecognizer(gestureRecognizer)
                return
            }

            existingGestureRecognizer.isEnabled = true
        }

        removeInputBarGestureRecognizers()

        guard let currentUser,
              inputBar.sendButton.isRecordButton else { return }

        guard currentUser.canSendAudioMessages else {
            addOrEnable(UITapGestureRecognizer(
                target: self,
                action: #selector(presentAudioMessagesUnsupportedAlert)
            ))
            return
        }

        guard services.permission.recordPermissionStatus == .granted,
              services.permission.transcribePermissionStatus == .granted else {
            addOrEnable(UITapGestureRecognizer(
                target: self,
                action: #selector(requestPermissions)
            ))
            return
        }

        let longPressGesture: UILongPressGestureRecognizer = .init(target: self, action: #selector(longPressGestureRecognized))
        longPressGesture.minimumPressDuration = Floats.longPressGestureMinimumPressDuration

        addOrEnable(longPressGesture)
        addOrEnable(UITapGestureRecognizer(
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
                coreGCD.after(.milliseconds(Floats.millisecondsDelay)) {
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
        let alert = AKAlert(
            message: Strings.audioMessagesUnsupportedAlertMessage,
            cancelButtonTitle: Strings.audioMessagesUnsupportedAlertCancelButtonTitle,
            sender: inputBar.sendButton
        )

        let isKeyboardFirstResponder = inputBar.inputTextView.isFirstResponder

        // NOTE: Encountered threading issues when using the asynchronous present() method.
        alert.present { _ in
            self.services.audio.acknowledgedAudioMessagesUnsupported = true
            self.chatPageViewService.inputBar?.configureInputBar(forRecording: false)

            self.coreGCD.after(.milliseconds(Floats.millisecondsDelay)) {
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
                    defer { configureInputBarGestureRecognizers() }

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
        Observables.rootViewToast.value = .init(
            .banner(style: .info, appearanceEdge: .bottom, showsDismissButton: false),
            message: Localized(.holdDownToRecord).wrappedValue,
            perpetuation: .ephemeral(.seconds(Floats.recordingInstructionToastPerpetuationDuration))
        )
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
            Observables.rootViewToast.value = .init(
                .banner(style: .error, appearanceEdge: .bottom, showsDismissButton: false),
                message: Localized(.tryAgain).wrappedValue,
                perpetuation: .ephemeral(.seconds(Floats.errorToastPerpetuationDuration))
            )
            return
        }

        Observables.rootViewToast.value = .init(
            .banner(style: .warning, appearanceEdge: .bottom, showsDismissButton: false),
            message: Localized(.noSpeechDetected).wrappedValue,
            perpetuation: .ephemeral(.seconds(Floats.errorToastPerpetuationDuration))
        )
    }
}
