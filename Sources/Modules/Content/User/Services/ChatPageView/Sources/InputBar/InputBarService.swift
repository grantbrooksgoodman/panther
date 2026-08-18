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

/// The service that manages the message input bar.
///
/// ``InputBarService`` configures the chat page's input bar and keeps it in sync with the
/// conversation's state. It switches the send button between its text-send and record
/// configurations, enables or disables the send, attach-media, and consent buttons, manages the
/// input field's first-responder status, and presents the sending state while a message is being
/// delivered. When the conversation requires message-receipt consent, it shows a consent button
/// in place of the input field.
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

    @SharedEvent(\.audioMessageCapabilityInventoryLoaded) private var audioMessageCapabilityInventoryLoaded
    @Dependency(\.build) private var build: Build
    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.clientSession.entity.conversation.currentConversation) private var currentConversation: Conversation?
    @Dependency(\.dataUsageService) private var dataUsageService: DataUsageService
    @Dependency(\.inputBarConfigService) private var inputBarConfigService: InputBarConfigService
    @Dependency(\.messageDeliveryService.isSendingMessage) private var isSendingMessage: Bool
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.uiApplication.mainScreen.bounds.width) private var screenWidth: CGFloat

    // MARK: - Properties

    /// The service that handles the input bar's button actions.
    let actionHandler: InputBarActionHandlerService

    /// A Boolean value that indicates whether the input bar's appearance is currently being
    /// forced.
    private(set) var isForcingAppearance = false

    private let viewController: ChatPageViewController

    @Cached(CacheKey.shouldShowRecordButton) private var cachedShouldShowRecordButton: (encodedConversationID: String, Bool)?
    private var inventoryObservationTask: Task<Void, Never>?

    // MARK: - Computed Properties

    /// A Boolean value that indicates whether the input field is the first responder.
    var isFirstResponder: Bool {
        inputBar.inputTextView.isFirstResponder
    }

    /// A Boolean value that indicates whether the consent button is currently shown.
    var isShowingConsentButton: Bool {
        (consentButton?.alpha ?? 0) > 0
    }

    /// A Boolean value that indicates whether the attach-media button should be enabled.
    var shouldEnableAttachMediaButton: Bool {
        getShouldEnableAttachMediaButton()
    }

    /// A Boolean value that indicates whether the send button should be enabled.
    var shouldEnableSendButton: Bool {
        getShouldEnableSendButton()
    }

    private var consentButton: UIButton? {
        inputBar.firstSubview(for: Strings.consentButtonSemanticTag) as? UIButton
    }

    private var inputBar: InputBarAccessoryView {
        viewController.messageInputBar
    }

    private var inputTextViewGlassEffectView: UIView? {
        inputBar.inputTextView.superview?.firstSubview(for: Strings.inputTextViewGlassEffectViewSemanticTag)
    }

    private var shouldEnableConsentButton: Bool {
        getShouldEnableConsentButton()
    }

    private var shouldShowConsentButton: Bool {
        getShouldShowConsentButton()
    }

    private var shouldShowRecordButton: Bool {
        getShouldShowRecordButton()
    }

    // MARK: - Object Lifecycle

    /// Creates the service, binding it to the given chat page view controller.
    ///
    /// - Parameter viewController: The chat page's messages view controller.
    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
        actionHandler = .init(viewController)

        // The record button depends on speech-capability inventories that load asynchronously after
        // launch; force a full reconfiguration – including gesture wiring – once they arrive so a
        // chat page opened pre-load updates itself without a reload.
        let inventoryLoadedEvents = audioMessageCapabilityInventoryLoaded.events
        inventoryObservationTask = Task { [weak self] in
            for await _ in inventoryLoadedEvents {
                guard let self else { return }
                cachedShouldShowRecordButton = nil
                configureInputBar(forceUpdate: true)
            }
        }
    }

    deinit {
        inventoryObservationTask?.cancel()
    }

    // MARK: - Configure Input Bar

    /// Configures the input bar for its current state.
    ///
    /// This method switches the send button between its text-send and record configurations –
    /// updating its image, tint, and enabled state – and enables or disables the attach-media
    /// button to match. When the current conversation requires message-receipt consent, it shows
    /// the consent button in place of the input field instead.
    ///
    /// - Parameters:
    ///   - forRecording: Whether to configure the send button for recording. Pass `nil` to
    ///     derive this from the input field's contents and the conversation's audio-message
    ///     support.
    ///   - forceUpdate: A Boolean value that determines whether to reconfigure the send button
    ///     even when it already matches the requested configuration.
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
                self.inputTextViewGlassEffectView?.alpha = 1
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
            inputBar.sendButton.tag = coreUI.semTag(for: Strings.recordButtonSemanticTag)

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
            inputBar.sendButton.tag = coreUI.semTag(for: Strings.sendButtonSemanticTag)
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

    /// Makes the input field the first responder, retrying until it succeeds while the chat page
    /// remains presented.
    ///
    /// This method has no effect while the consent button is shown.
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

    /// Forces the input bar to reappear when it has been unexpectedly hidden, restoring
    /// first-responder status to the recipient bar's text field.
    ///
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

    /// Updates the attach-media button's images for the current interface style.
    func setAttachMediaButtonImage() {
        let attachMediaButtonNormalImage = inputBarConfigService.attachMediaButtonImage(isHighlighted: false)
        let attachMediaButtonHighlightedImage = inputBarConfigService.attachMediaButtonImage(isHighlighted: true)

        inputBar.leftStackView.attachMediaButton?.setImage(attachMediaButtonNormalImage, for: .normal)
        inputBar.leftStackView.attachMediaButton?.setImage(attachMediaButtonHighlightedImage, for: .highlighted)
    }

    // MARK: - Set Attach Media Button Is Enabled

    /// Sets whether the attach-media button is enabled, animating the change.
    ///
    /// - Parameter isEnabled: A Boolean value that indicates whether the attach-media button is
    ///   enabled.
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

    /// Sets whether the consent button is enabled.
    ///
    /// - Parameter isEnabled: A Boolean value that indicates whether the consent button is
    ///   enabled.
    func setConsentButtonIsEnabled(_ isEnabled: Bool) {
        guard let consentButton else { return }
        consentButton.isEnabled = isEnabled
        consentButton.isUserInteractionEnabled = isEnabled
        consentButton.setTitleColor(isEnabled ? .accentOrSystemBlue : .disabled, for: .normal)
    }

    // MARK: - Set Send Button Is Enabled

    /// Sets whether the send button is enabled, animating the change.
    ///
    /// - Parameter isEnabled: A Boolean value that indicates whether the send button is enabled.
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

    /// Shows or hides the input bar's sending state.
    ///
    /// While the sending state is shown, the send button animates and the input field and
    /// attach-media button are disabled.
    ///
    /// - Parameters:
    ///   - on: A Boolean value that indicates whether to show the sending state.
    ///   - clearInputTextViewText: A Boolean value that determines whether to clear the input
    ///     field's text when showing the sending state.
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
              !dataUsageService.atOrAboveDataUsageLimit else { return false }

        let isConversationEmpty = viewController.currentConversation?.isEmpty ?? true
        let isRecipientBarFirstResponder = chatPageViewService.recipientBar?.layout.textField?.isFirstResponder ?? false

        return !isConversationEmpty && !isRecipientBarFirstResponder && !isSendingMessage
    }

    private func getShouldEnableConsentButton() -> Bool {
        guard let currentConversation else { return false }
        if let selectedContactPairs = chatPageViewService
            .recipientBar?
            .contactSelectionUI
            .selectedContactPairs,
            selectedContactPairs.contains(where: \.isMock) {
            return false
        }

        let didSendConsentMessage = currentConversation.didSendConsentMessage
        let grantedConsent = currentConversation.currentUserGrantedMessageReceiptConsent
        let requiresConsent = currentConversation.currentUserInitiatorRequiresMessageReceiptConsent

        return (!grantedConsent || (requiresConsent && !didSendConsentMessage)) && !isSendingMessage
    }

    private func getShouldEnableSendButton() -> Bool {
        guard !dataUsageService.atOrAboveDataUsageLimit else { return false }

        let isConversationEmpty = viewController.currentConversation?.isEmpty ?? true
        let isRecipientBarFirstResponder = chatPageViewService.recipientBar?.layout.textField?.isFirstResponder ?? false
        let isSendButtonConfiguredForText = !inputBar.sendButton.isRecordButton

        // Audio/media recording requires connectivity; text sends are allowed
        // offline and handled by the outbox fail-fast → auto-retry path.
        guard isSendButtonConfiguredForText else {
            guard build.isOnline else { return false }
            return !isConversationEmpty &&
                !isRecipientBarFirstResponder &&
                !isSendingMessage
        }

        if !build.isOnline,
           navigation.state.userContent.sheet == .newChat {
            return false
        }

        let isTextViewTextBlank = inputBar.inputTextView.text.sanitized.isBlank
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
              let currentConversation else { return }

        consentButton.addTarget(
            actionHandler,
            action: #selector(actionHandler.didPressConsentButton),
            for: .touchUpInside
        )

        consentButton.isEnabled = shouldEnableConsentButton
        consentButton.isUserInteractionEnabled = shouldEnableConsentButton

        consentButton.setTitle(
            Localized(
                currentConversation.currentUserInitiatorRequiresMessageReceiptConsent ?
                    (currentConversation.didSendConsentMessage ? .awaitingConsent : .requestConsent) :
                    .acknowledgeConsent
            ).wrappedValue,
            for: .normal
        )

        consentButton.setTitleColor(
            shouldEnableConsentButton || (
                currentConversation
                    .currentUserInitiatorRequiresMessageReceiptConsent && currentConversation
                    .didSendConsentMessage
            ) ? .accentOrSystemBlue : .disabled,
            for: .normal
        )

        consentButton.titleLabel?.font = consentButton.title(for: .normal) == Localized(.awaitingConsent).wrappedValue ?
            .systemFont(ofSize: Floats.consentButtonFontSize) :
            .boldSystemFont(ofSize: Floats.consentButtonFontSize)

        consentButton.frame.size = consentButton.intrinsicContentSize
        while consentButton.frame.width > screenWidth {
            consentButton.frame.size.width -= 1
        }
        consentButton.frame.size.width -= Floats.consentButtonFrameWidthDecrement

        consentButton.titleLabel?.adjustsFontSizeToFitWidth = true
        consentButton.titleLabel?.minimumScaleFactor = Floats.consentButtonTitleLabelMinimumScaleFactor
        consentButton.center = inputBar.center

        if !(currentConversation.currentUserInitiatorRequiresMessageReceiptConsent && currentConversation.didSendConsentMessage) {
            consentButton.removeShimmerEffect()
        }

        UIView.animate(withDuration: Floats.transitionAnimationDuration) {
            self.inputBar.inputTextView.alpha = 0
            self.inputBar.leftStackView.alpha = 0
            self.inputBar.sendButton.alpha = 0
            self.inputTextViewGlassEffectView?.alpha = 0
            consentButton.alpha = 1
        } completion: { _ in
            guard currentConversation.currentUserInitiatorRequiresMessageReceiptConsent,
                  currentConversation.didSendConsentMessage else { return }
            consentButton.addShimmerEffect()
        }
    }
}

// swiftlint:enable file_length type_body_length
