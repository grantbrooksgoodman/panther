//
//  InputBarService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import InputBarAccessoryView

@MainActor
final class InputBarService {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case shouldShowRecordButton
    }

    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatPageViewService.InputBar
    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.InputBar
    private typealias Strings = AppConstants.Strings.ChatPageViewService.InputBar

    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.inputBarConfigService) private var inputBarConfigService: InputBarConfigService
    @Dependency(\.messageDeliveryService.isSendingMessage) private var isSendingMessage: Bool
    @Dependency(\.uiApplication.mainScreen.bounds.width) private var screenWidth: CGFloat

    // MARK: - Properties

    let actionHandler: InputBarActionHandlerService

    private(set) var isForcingAppearance = false

    private let viewController: ChatPageViewController

    @Cached(CacheKey.shouldShowRecordButton) private var cachedShouldShowRecordButton: (encodedConversationID: String, Bool)?

    // MARK: - Computed Properties

    var isFirstResponder: Bool { inputBar.inputTextView.isFirstResponder }
    var isShowingConsentButton: Bool { (consentButton?.alpha ?? 0) > 0 }
    var shouldEnableAttachMediaButton: Bool { getShouldEnableAttachMediaButton() }
    var shouldEnableSendButton: Bool { getShouldEnableSendButton() }

    private var consentButton: UIButton? { inputBar.firstSubview(for: Strings.consentButtonSemanticTag) as? UIButton }
    private var inputBar: InputBarAccessoryView { viewController.messageInputBar }
    private var shouldEnableConsentButton: Bool { getShouldEnableConsentButton() }
    private var shouldShowConsentButton: Bool { getShouldShowConsentButton() }
    private var shouldShowRecordButton: Bool { getShouldShowRecordButton() }

    // MARK: - Init

    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
        actionHandler = .init(viewController)
    }

    // MARK: - Configure Input Bar

    func configureInputBar(
        forRecording: Bool? = nil,
        forceUpdate: Bool = false
    ) {
        guard !shouldShowConsentButton else { return showConsentButton() }
        if inputBar.inputTextView.alpha == 0 {
            UIView.animate(withDuration: Floats.transitionAnimationDuration) {
                self.consentButton?.alpha = 0
                self.inputBar.inputTextView.alpha = 1
                self.inputBar.leftStackView.alpha = 1
                self.inputBar.sendButton.alpha = 1
            }
        }

        let forRecording = forRecording ?? shouldShowRecordButton
        if !forceUpdate {
            switch forRecording {
            case true:
                guard !inputBar.sendButton.isRecordButton else { return }

            case false:
                guard inputBar.sendButton.isRecordButton else {
                    inputBar.leftStackView.attachMediaButton?.isEnabled = shouldEnableAttachMediaButton
                    inputBar.sendButton.isEnabled = shouldEnableSendButton
                    return
                }
            }
        }

        inputBar.sendButton.centerYAnchor.constraint(
            equalTo: inputBar.contentView.centerYAnchor,
            constant: 0
        ).isActive = true

        inputBar.sendButton.trailingAnchor.constraint(
            equalTo: inputBar.contentView.trailingAnchor,
            constant: -(inputBar.sendButton.frame.width - Floats.sendButtonTrailingAnchorConstraintConstantDecrement)
        ).isActive = true

        switch forRecording {
        case true:
            inputBar.sendButton.tag = core.ui.semTag(for: Strings.recordButtonSemanticTag)

            UIView.transition(
                with: inputBar.sendButton,
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
            inputBar.sendButton.tag = core.ui.semTag(for: Strings.sendButtonSemanticTag)
            chatPageViewService.inputBarGestureRecognizer?.removeInputBarGestureRecognizers()

            UIView.transition(
                with: inputBar.sendButton,
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

    // MARK: - Become First Responder

    func becomeFirstResponder() {
        guard !shouldShowConsentButton else { return }
        let startDate = Date.now
        while chatPageState.isPresented,
              !inputBar.inputTextView.isFirstResponder,
              abs(startDate.seconds(from: .now)) < 5 {
            guard inputBar.inputTextView.canBecomeFirstResponder else { break }
            inputBar.inputTextView.becomeFirstResponder()
        }
    }

    // MARK: - Force Appearance

    /// - NOTE: Fixes a bug in which the dismissal of the contact selector sheet would cause the input bar to hide.
    func forceAppearance() {
        guard let textField = chatPageViewService.recipientBar?.layout.textField else { return }

        viewController.view.isUserInteractionEnabled = false
        isForcingAppearance = true

        Logger.log(
            "Intercepted input bar disappearance bug.",
            domain: .bugPrevention,
            sender: self
        )

        becomeFirstResponder()
        Task.delayed(by: .milliseconds(Floats.forceAppearanceDelayMilliseconds)) { @MainActor in
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

    func setAttachMediaButtonImage() {
        let attachMediaButtonNormalImage = inputBarConfigService.attachMediaButtonImage(isHighlighted: false)
        let attachMediaButtonHighlightedImage = inputBarConfigService.attachMediaButtonImage(isHighlighted: true)

        inputBar.leftStackView.attachMediaButton?.setImage(attachMediaButtonNormalImage, for: .normal)
        inputBar.leftStackView.attachMediaButton?.setImage(attachMediaButtonHighlightedImage, for: .highlighted)
    }

    // MARK: - Set Attach Media Button Is Enabled

    func setAttachMediaButtonIsEnabled(_ isEnabled: Bool) {
        if !isForcingAppearance {
            guard inputBar.leftStackView.attachMediaButton?.isEnabled != isEnabled else { return }
        }

        guard let attachMediaButton = inputBar.leftStackView.attachMediaButton else { return }

        UIView.transition(
            with: attachMediaButton,
            duration: Floats.transitionAnimationDuration,
            options: [.transitionCrossDissolve]
        ) {
            attachMediaButton.isEnabled = isEnabled
        }
    }

    // MARK: - Set Consent Button Is Enabled

    func setConsentButtonIsEnabled(_ isEnabled: Bool) {
        guard let consentButton else { return }
        consentButton.isEnabled = isEnabled
        consentButton.isUserInteractionEnabled = isEnabled
        consentButton.setTitleColor(isEnabled ? .accentOrSystemBlue : .disabled, for: .normal)
    }

    // MARK: - Set Send Button Is Enabled

    func setSendButtonIsEnabled(_ isEnabled: Bool) {
        if !isForcingAppearance {
            guard inputBar.sendButton.isEnabled != isEnabled else { return }
        }

        UIView.transition(
            with: inputBar.sendButton,
            duration: Floats.transitionAnimationDuration,
            options: [.transitionCrossDissolve]
        ) {
            self.inputBar.sendButton.isEnabled = isEnabled
        }
    }

    // MARK: - Toggle Sending UI

    func toggleSendingUI(
        on: Bool,
        clearInputTextViewText: Bool = true
    ) {
        if on {
            defer {
                inputBar.sendButton.startAnimating()
                setAttachMediaButtonIsEnabled(false)
            }

            guard clearInputTextViewText else { return }
            inputBar.inputTextView.text = ""
        } else {
            inputBar.sendButton.stopAnimating()
            setAttachMediaButtonIsEnabled(shouldEnableAttachMediaButton)
        }

        inputBar.inputTextView.tintColor = UIColor(on ? Colors.inputTextViewAlternateTint : Colors.inputTextViewTint)
        inputBar.leftStackView.attachMediaButton?.isUserInteractionEnabled = !on
        inputBar.sendButton.isUserInteractionEnabled = !on
    }

    // MARK: - Computed Property Getters

    private func getShouldEnableAttachMediaButton() -> Bool {
        guard build.isOnline,
              !clientSession.storage.atOrAboveDataUsageLimit else { return false }

        let isConversationEmpty = viewController.currentConversation?.isEmpty ?? true
        let isRecipientBarFirstResponder = chatPageViewService.recipientBar?.layout.textField?.isFirstResponder ?? false

        return !isConversationEmpty && !isRecipientBarFirstResponder && !isSendingMessage
    }

    private func getShouldEnableConsentButton() -> Bool {
        guard let fullConversation = clientSession.conversation.fullConversation else { return false }
        if let selectedContactPairs = chatPageViewService
            .recipientBar?
            .contactSelectionUI
            .selectedContactPairs,
            selectedContactPairs.contains(where: \.isMock) {
            return false
        }

        let didSendConsentMessage = fullConversation.didSendConsentMessage
        let grantedConsent = fullConversation.currentUserGrantedMessageReceiptConsent
        let requiresConsent = fullConversation.currentUserInitiatorRequiresMessageReceiptConsent

        return (!grantedConsent || (requiresConsent && !didSendConsentMessage)) && !isSendingMessage
    }

    private func getShouldEnableSendButton() -> Bool {
        guard build.isOnline,
              !clientSession.storage.atOrAboveDataUsageLimit else { return false }

        let isConversationEmpty = viewController.currentConversation?.isEmpty ?? true
        let isRecipientBarFirstResponder = chatPageViewService.recipientBar?.layout.textField?.isFirstResponder ?? false
        let isSendButtonConfiguredForText = !inputBar.sendButton.isRecordButton
        let isTextViewTextBlank = inputBar.inputTextView.text.sanitized.isBlank

        guard isSendButtonConfiguredForText else { return !isConversationEmpty && !isRecipientBarFirstResponder && !isSendingMessage }
        return !isConversationEmpty && !isRecipientBarFirstResponder && !isSendingMessage && !isTextViewTextBlank
    }

    private func getShouldShowConsentButton() -> Bool {
        if consentButton?.alpha == 1,
           isSendingMessage {
            return true
        }

        guard let currentConversation = viewController.currentConversation,
              !currentConversation.isEmpty else { return false }
        return currentConversation.currentUserInitiatorRequiresMessageReceiptConsent || !currentConversation.currentUserGrantedMessageReceiptConsent
    }

    private func getShouldShowRecordButton() -> Bool {
        let isTextViewTextEmpty = inputBar.inputTextView.text.sanitized.isEmpty
        if !isTextViewTextEmpty,
           let cachedValue = cachedShouldShowRecordButton,
           cachedValue.encodedConversationID == viewController.currentConversation?.id.encoded {
            return cachedValue.1
        }

        let canShowRecordButton = inputBarConfigService.canShowRecordButton
        let shouldConfigureForRecording = canShowRecordButton && isTextViewTextEmpty

        guard !isTextViewTextEmpty else { return shouldConfigureForRecording }
        cachedShouldShowRecordButton = (
            viewController.currentConversation?.id.encoded ?? .bangQualifiedEmpty,
            shouldConfigureForRecording
        )

        return shouldConfigureForRecording
    }

    // MARK: - Auxiliary

    private func showConsentButton() {
        guard let consentButton,
              let fullConversation = clientSession.conversation.fullConversation else { return }

        consentButton.addTarget(
            actionHandler,
            action: #selector(actionHandler.didPressConsentButton),
            for: .touchUpInside
        )

        consentButton.isEnabled = shouldEnableConsentButton
        consentButton.isUserInteractionEnabled = shouldEnableConsentButton

        consentButton.setTitle(
            Localized(
                fullConversation.currentUserInitiatorRequiresMessageReceiptConsent ?
                    (fullConversation.didSendConsentMessage ? .awaitingConsent : .requestConsent) :
                    .acknowledgeConsent
            ).wrappedValue,
            for: .normal
        )

        consentButton.setTitleColor(
            shouldEnableConsentButton || (fullConversation
                .currentUserInitiatorRequiresMessageReceiptConsent && fullConversation
                .didSendConsentMessage) ? .accentOrSystemBlue : .disabled,
            for: .normal
        )

        consentButton.titleLabel?.font = consentButton.title(for: .normal) == Localized(.awaitingConsent).wrappedValue ?
            .systemFont(ofSize: Floats.consentButtonFontSize) :
            .boldSystemFont(ofSize: Floats.consentButtonFontSize)

        consentButton.frame.size = consentButton.intrinsicContentSize
        while consentButton.frame.width > screenWidth { consentButton.frame.size.width -= 1 }
        consentButton.frame.size.width -= Floats.consentButtonFrameWidthDecrement

        consentButton.titleLabel?.adjustsFontSizeToFitWidth = true
        consentButton.titleLabel?.minimumScaleFactor = Floats.consentButtonTitleLabelMinimumScaleFactor
        consentButton.center = inputBar.center

        if !(fullConversation.currentUserInitiatorRequiresMessageReceiptConsent && fullConversation.didSendConsentMessage) {
            consentButton.removeShimmerEffect()
        }

        UIView.animate(withDuration: Floats.transitionAnimationDuration) {
            self.inputBar.inputTextView.alpha = 0
            self.inputBar.leftStackView.alpha = 0
            self.inputBar.sendButton.alpha = 0
            consentButton.alpha = 1
        } completion: { _ in
            guard fullConversation.currentUserInitiatorRequiresMessageReceiptConsent,
                  fullConversation.didSendConsentMessage else { return }
            consentButton.addShimmerEffect()
        }
    }
}

// swiftlint:enable file_length type_body_length
