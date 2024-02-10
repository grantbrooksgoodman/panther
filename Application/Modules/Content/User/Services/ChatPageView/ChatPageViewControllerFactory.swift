//
//  ChatPageViewControllerFactory.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 02/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import MessageKit
import Redux

public struct ChatPageViewControllerFactory {
    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.inputBarConfigService) private var inputBarConfigService: InputBarConfigService
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

    public func configureBackgroundColor(_ viewController: ChatPageViewController) {
        viewController.messagesCollectionView.backgroundColor = .background
        viewController.messagesCollectionView.backgroundView?.backgroundColor = .background
        viewController.view.backgroundColor = .background
    }

    public func configureCollectionViewLayout(_ viewController: ChatPageViewController) {
        typealias Floats = AppConstants.CGFloats.ChatPageView

        guard let layout = viewController.messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout else { return }

        layout.attributedTextMessageSizeCalculator.outgoingAvatarSize = .zero
        layout.audioMessageSizeCalculator.outgoingAvatarSize = .zero
        layout.textMessageSizeCalculator.outgoingAvatarSize = .zero

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
        typealias Floats = AppConstants.CGFloats.DeliveryProgressIndicatorService
        typealias Strings = AppConstants.Strings.DeliveryProgressIndicatorService

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

    public func configureInitialInputBar(_ viewController: ChatPageViewController) {
        typealias Colors = AppConstants.Colors.InputBarService
        typealias Floats = AppConstants.CGFloats.InputBarService
        typealias Strings = AppConstants.Strings.InputBarService

        let inputBar = viewController.messageInputBar

        inputBar.backgroundView.backgroundColor = .inputBarBackground

        inputBar.setStackViewItems([viewController.messageInputBar.sendButton], forStack: .right, animated: false)
        inputBar.rightStackView.alignment = .center

        let canConfigureInputBarForRecording = inputBarConfigService.canConfigureInputBarForRecording

        // swiftlint:disable line_length
        let contentViewBorderColor = UIColor(canConfigureInputBarForRecording ? Colors.contentViewRecordLayerBorder : Colors.contentViewTextLayerBorder).cgColor
        let inputTextViewBorderColor = UIColor(canConfigureInputBarForRecording ? Colors.inputTextViewRecordLayerBorder : Colors.inputTextViewRecordLayerBorder).cgColor
        // swiftlint:enable line_length

        inputBar.contentView.clipsToBounds = true
        inputBar.contentView.layer.borderColor = contentViewBorderColor
        inputBar.contentView.layer.borderWidth = Floats.layerBorderWidth
        inputBar.contentView.layer.cornerRadius = Floats.layerCornerRadius

        inputBar.inputTextView.clipsToBounds = true
        inputBar.inputTextView.layer.borderColor = inputTextViewBorderColor
        inputBar.inputTextView.layer.borderWidth = Floats.layerBorderWidth
        inputBar.inputTextView.layer.cornerRadius = Floats.layerCornerRadius

        inputBar.inputTextView.delegate = viewController
        inputBar.inputTextView.placeholder = " \(Localized(.newMessage).wrappedValue)"
        inputBar.inputTextView.tintColor = .accent

        inputBar.sendButton.setSize(
            .init(width: Floats.sendButtonSizeWidth, height: Floats.sendButtonSizeHeight),
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

        inputBar.sendButton.tag = canConfigureInputBarForRecording ? recordButtonSemanticTag : sendButtonSemanticTag
        inputBar.sendButton.tintColor = canConfigureInputBarForRecording ? .init(Colors.sendButtonRecordTint) : .init(Colors.sendButtonTextTint)

        inputBar.sendButton
            .onSelected { $0.transform = CGAffineTransform(
                scaleX: Floats.sendButtonOnSelectedTransformScaleX,
                y: Floats.sendButtonOnSelectedTransformScaleY
            ) }
            .onDeselected { $0.transform = .identity }
    }
}
