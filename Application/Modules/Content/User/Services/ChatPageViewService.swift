//
//  ChatPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 31/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import MessageKit
import Redux

public final class ChatPageViewService {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatPageView
    private typealias Floats = AppConstants.CGFloats.ChatPageView
    private typealias Strings = AppConstants.Strings.ChatPageView

    // MARK: - Dependencies

    @Dependency(\.commonServices.audio) private var audioService: AudioService
    @Dependency(\.clientSession) private var clientSession: ClientSession

    // MARK: - Properties

    private var viewController: ChatPageViewController?

    // MARK: - Computed Properties

    private var shouldConfigureInputBarForText: Bool {
        guard let currentUser = clientSession.user.currentUser,
              let conversation = clientSession.conversation.currentConversation else { return true }

        guard currentUser.canSendAudioMessages else { return audioService.acknowledgedAudioMessagesUnsupported ?? false }
        guard let users = conversation.users else { return !conversation.isMock /* TODO: Audit this. */ }
        return !users.allSatisfy { currentUser.canSendAudioMessages(to: $0) }
    }

    // MARK: - View Controller Creation

    public func createViewController(_ conversation: Conversation) -> MessagesViewController {
        let viewController = ChatPageViewController()

        clientSession.conversation.setCurrentConversation(conversation)

        viewController.messagesCollectionView.messageCellDelegate = viewController
        viewController.messagesCollectionView.messagesDataSource = viewController
        viewController.messagesCollectionView.messagesDisplayDelegate = viewController
        viewController.messagesCollectionView.messagesLayoutDelegate = viewController
        viewController.messageInputBar.delegate = viewController

        viewController.scrollsToLastItemOnKeyboardBeginsEditing = true
        viewController.showMessageTimestampOnSwipeLeft = true

        self.viewController = viewController

        configureCollectionViewLayout()
        configureBackgroundColor()
        configureInitialInputBar()

        return viewController
    }

    // MARK: - UI Configuration

    public func configureBackgroundColor() {
        viewController?.messagesCollectionView.backgroundColor = .background
        viewController?.messagesCollectionView.backgroundView?.backgroundColor = .background
        viewController?.view.backgroundColor = .background
    }

    public func configureCollectionViewLayout() {
        guard let layout = viewController?.messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout else { return }

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

    public func configureInitialInputBar() {
        guard let viewController else { return }
        let inputBar = viewController.messageInputBar

        inputBar.backgroundView.backgroundColor = .inputBarBackground

        inputBar.setStackViewItems([viewController.messageInputBar.sendButton], forStack: .right, animated: false)
        inputBar.rightStackView.alignment = .center

        // swiftlint:disable line_length
        let contentViewBorderColor = UIColor(shouldConfigureInputBarForText ? Colors.inputBarContentViewTextLayerBorder : Colors.inputBarContentViewRecordLayerBorder).cgColor
        let inputTextViewBorderColor = UIColor(shouldConfigureInputBarForText ? Colors.inputBarInputTextViewTextLayerBorder : Colors.inputBarInputTextViewRecordLayerBorder).cgColor
        // swiftlint:enable line_length

        inputBar.contentView.clipsToBounds = true
        inputBar.contentView.layer.borderColor = contentViewBorderColor
        inputBar.contentView.layer.borderWidth = Floats.inputBarLayerBorderWidth
        inputBar.contentView.layer.cornerRadius = Floats.inputBarLayerCornerRadius

        inputBar.inputTextView.clipsToBounds = true
        inputBar.inputTextView.layer.borderColor = inputTextViewBorderColor
        inputBar.inputTextView.layer.borderWidth = Floats.inputBarLayerBorderWidth
        inputBar.inputTextView.layer.cornerRadius = Floats.inputBarLayerCornerRadius

        inputBar.inputTextView.delegate = viewController
        inputBar.inputTextView.placeholder = " \(Localized(.newMessage).wrappedValue)"
        inputBar.inputTextView.tintColor = .accent

        let sendButtonNormalImage = sendButtonImage(forRecording: !shouldConfigureInputBarForText, isHighlighted: false)
        let sendButtonHighlightedImage = sendButtonImage(forRecording: !shouldConfigureInputBarForText, isHighlighted: true)

        inputBar.sendButton.setSize(
            .init(width: Floats.inputBarSendButtonSizeWidth, height: Floats.inputBarSendButtonSizeHeight),
            animated: false
        )

        inputBar.sendButton.setImage(sendButtonNormalImage, for: .normal)
        inputBar.sendButton.setImage(sendButtonHighlightedImage, for: .highlighted)
        inputBar.sendButton.tintColor = shouldConfigureInputBarForText ? .init(Colors.inputBarSendButtonTextTint) : .init(Colors.inputBarSendButtonRecordTint)

        inputBar.sendButton
            .onSelected { $0.transform = CGAffineTransform(
                scaleX: Floats.inputBarSendButtonOnSelectedTransformScaleX,
                y: Floats.inputBarSendButtonOnSelectedTransformScaleY
            ) }
            .onDeselected { $0.transform = .identity }
    }

    // MARK: - Auxiliary

    public func reloadCollectionView() {
        Task { @MainActor in
            viewController?.messagesCollectionView.reloadDataAndKeepOffset()
        }
    }

    private func sendButtonImage(forRecording: Bool, isHighlighted: Bool) -> UIImage? {
        guard forRecording else {
            guard ThemeService.isDefaultThemeApplied else {
                return .init(named: isHighlighted ? Strings.sendButtonAlternateHighlightedImageName : Strings.sendButtonAlternateDefaultImageName)
            }

            return .init(named: isHighlighted ? Strings.sendButtonPrimaryHighlightedImageName : Strings.sendButtonPrimaryDefaultImageName)
        }

        return .init(named: isHighlighted ? Strings.recordButtonHighlightedImageName : Strings.recordButtonDefaultImageName)
    }
}
