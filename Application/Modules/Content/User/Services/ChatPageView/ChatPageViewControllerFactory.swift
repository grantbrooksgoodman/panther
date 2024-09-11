//
//  ChatPageViewControllerFactory.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 02/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import InputBarAccessoryView
import MessageKit

public struct ChatPageViewControllerFactory {
    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.inputBarConfigService) private var inputBarConfigService: InputBarConfigService
    @Dependency(\.chatPageViewService.inputBar) private var inputBarService: InputBarService?
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Build View Controller

    public func buildViewController() -> ChatPageViewController {
        let viewController = ChatPageViewController()

        viewController.messagesCollectionView.messageCellDelegate = viewController
        viewController.messagesCollectionView.messagesDataSource = viewController
        viewController.messagesCollectionView.messagesDisplayDelegate = viewController
        viewController.messagesCollectionView.messagesLayoutDelegate = viewController
        viewController.messageInputBar.delegate = viewController

        viewController.scrollsToLastItemOnKeyboardBeginsEditing = true
        viewController.showMessageTimestampOnSwipeLeft = true

        configureCollectionViewLayout(viewController)
        configureBackgroundColor(viewController)
        configureDeliveryProgressView(viewController)
        configureInitialInputBar(viewController)

        return viewController
    }

    // MARK: - UI Configuration

    public func configureRecipientBar(_ viewController: ChatPageViewController, service: RecipientBarService) {
        typealias Floats = AppConstants.CGFloats.ChatPageViewService.RecipientBarService.Layout
        typealias Strings = AppConstants.Strings.ChatPageViewService.RecipientBarService.Layout

        viewController.messagesCollectionView.contentInset.top = Floats.frameHeight
        viewController.messagesCollectionView.verticalScrollIndicatorInsets.top = Floats.frameHeight

        let recipientBar = RecipientBar(service: service)
        recipientBar.tag = coreUI.semTag(for: Strings.recipientBarSemanticTag)
        viewController.view.addSubview(recipientBar)
    }

    private func configureBackgroundColor(_ viewController: ChatPageViewController) {
        viewController.messagesCollectionView.backgroundColor = .background
        viewController.messagesCollectionView.backgroundView?.backgroundColor = .background
        viewController.view.backgroundColor = viewController.messagesCollectionView.backgroundColor
    }

    private func configureCollectionViewLayout(_ viewController: ChatPageViewController) {
        typealias Floats = AppConstants.CGFloats.ChatPageView

        guard let layout = viewController.messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout else { return }

        layout.attributedTextMessageSizeCalculator.outgoingAvatarSize = .zero
        layout.audioMessageSizeCalculator.outgoingAvatarSize = .zero
        layout.photoMessageSizeCalculator.outgoingAvatarSize = .zero
        layout.textMessageSizeCalculator.outgoingAvatarSize = .zero
        layout.videoMessageSizeCalculator.outgoingAvatarSize = .zero

        layout.setMessageOutgoingCellBottomLabelAlignment(.init(
            textAlignment: .right,
            textInsets: .init(
                top: Floats.messageOutgoingCellBottomLabelAlignmentTopTextInset,
                left: 0,
                bottom: 0,
                right: Floats.messageOutgoingCellBottomLabelAlignmentRightTextInset
            )
        ))
    }

    private func configureDeliveryProgressView(_ viewController: ChatPageViewController) {
        typealias Floats = AppConstants.CGFloats.ChatPageViewService.DeliveryProgressIndicator
        typealias Strings = AppConstants.Strings.ChatPageViewService.DeliveryProgressIndicator

        guard let mainScreen = uiApplication.mainScreen else { return }

        let deliveryProgressView: UIProgressView = .init(
            frame: .init(
                x: 0,
                y: 0,
                width: mainScreen.bounds.width,
                height: Floats.viewFrameHeight
            )
        )

        deliveryProgressView.progress = 0
        deliveryProgressView.progressTintColor = .accent
        deliveryProgressView.progressViewStyle = .bar

        deliveryProgressView.tag = coreUI.semTag(for: Strings.viewSemanticTag)
        viewController.view.addSubview(deliveryProgressView)
    }

    private func configureInitialInputBar(_ viewController: ChatPageViewController) {
        typealias Colors = AppConstants.Colors.ChatPageViewService.InputBar
        typealias Floats = AppConstants.CGFloats.ChatPageViewService.InputBar
        typealias Strings = AppConstants.Strings.ChatPageViewService.InputBar

        let inputBar = viewController.messageInputBar

        // Configure attach media button

        let attachMediaButton = InputBarButtonItem(frame: .zero)
        attachMediaButton.setSize(
            .init(width: Floats.buttonSizeWidth, height: Floats.buttonSizeHeight),
            animated: false
        )

        let attachMediaButtonNormalImage = inputBarConfigService.attachMediaButtonImage(isHighlighted: false)
        let attachMediaButtonHighlightedImage = inputBarConfigService.attachMediaButtonImage(isHighlighted: true)

        attachMediaButton.setImage(attachMediaButtonNormalImage, for: .normal)
        attachMediaButton.setImage(attachMediaButtonHighlightedImage, for: .highlighted)

        attachMediaButton.isEnabled = false
        attachMediaButton.tag = coreUI.semTag(for: Strings.attachMediaButtonSemanticTag)

        attachMediaButton
            .onSelected { $0.transform = .init(
                scaleX: Floats.buttonOnSelectedTransformScaleX,
                y: Floats.buttonOnSelectedTransformScaleY
            ) }
            .onDeselected { $0.transform = .identity }

        attachMediaButton.onTouchUpInside { _ in inputBarService?.didPressAttachMediaButton() }

        // Configure send button

        inputBar.sendButton.setSize(
            .init(width: Floats.buttonSizeWidth, height: Floats.buttonSizeHeight),
            animated: false
        )

        let sendButtonNormalImage = inputBarConfigService.sendButtonImage(
            forRecording: inputBarConfigService.canConfigureInputBarForRecording,
            isHighlighted: false
        )
        let sendButtonHighlightedImage = inputBarConfigService.sendButtonImage(
            forRecording: inputBarConfigService.canConfigureInputBarForRecording,
            isHighlighted: true
        )

        inputBar.sendButton.setImage(sendButtonNormalImage, for: .normal)
        inputBar.sendButton.setImage(sendButtonHighlightedImage, for: .highlighted)

        let recordButtonSemanticTag = coreUI.semTag(for: Strings.recordButtonSemanticTag)
        let sendButtonSemanticTag = coreUI.semTag(for: Strings.sendButtonSemanticTag)
        let canConfigureInputBarForRecording = inputBarConfigService.canConfigureInputBarForRecording

        inputBar.sendButton.tag = canConfigureInputBarForRecording ? recordButtonSemanticTag : sendButtonSemanticTag
        inputBar.sendButton.tintColor = canConfigureInputBarForRecording ? .init(Colors.sendButtonRecordTint) : .init(Colors.sendButtonTextTint)
        inputBar.sendButton.title = nil

        inputBar.sendButton
            .onSelected { $0.transform = .init(
                scaleX: Floats.buttonOnSelectedTransformScaleX,
                y: Floats.buttonOnSelectedTransformScaleY
            ) }
            .onDeselected { $0.transform = .identity }

        inputBar.sendButton.alpha = 0

        // Configure stack views

        inputBar.leftStackView.alignment = .center
        inputBar.setLeftStackViewWidthConstant(to: Floats.leftStackViewWidthConstant, animated: false)
        inputBar.setStackViewItems(
            [
                attachMediaButton,
                InputBarButtonItem.fixedSpace(Floats.leftStackViewFixedSpaceWidth),
            ],
            forStack: .left,
            animated: false
        )

        inputBar.setRightStackViewWidthConstant(to: 0, animated: false)

        // Configure input text view

        inputBar.inputTextView.addSubview(viewController.messageInputBar.sendButton)

        inputBar.inputTextView.clipsToBounds = true
        inputBar.inputTextView.layer.borderColor = UIColor(Colors.inputTextViewLayerBorder).cgColor
        inputBar.inputTextView.layer.borderWidth = Floats.layerBorderWidth
        inputBar.inputTextView.layer.cornerRadius = Floats.layerCornerRadius

        inputBar.inputTextView.delegate = viewController
        inputBar.inputTextView.placeholder = " \(Localized(.newMessage).wrappedValue)"
        inputBar.inputTextView.textContainerInset.right = inputBar.sendButton.frame.width + Floats.textContainerInsetRightIncrement
        inputBar.inputTextView.tintColor = .accent
    }
}
