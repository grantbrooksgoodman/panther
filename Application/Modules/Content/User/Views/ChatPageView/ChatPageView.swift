//
//  ChatPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 30/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import MessageKit

public struct ChatPageView: UIViewControllerRepresentable {
    // MARK: - Type Aliases

    public typealias UIViewControllerType = MessagesViewController

    // MARK: - Properties

    private let conversation: Conversation

    // MARK: - Init

    public init(_ conversation: Conversation) {
        self.conversation = conversation
    }

    // MARK: - Make UIViewController

    public func makeUIViewController(context: Context) -> MessagesViewController {
        let viewController = ChatPageViewController()

        viewController.setConversation(conversation)

        viewController.messagesCollectionView.messageCellDelegate = viewController
        viewController.messagesCollectionView.messagesDataSource = viewController
        viewController.messagesCollectionView.messagesDisplayDelegate = viewController
        viewController.messagesCollectionView.messagesLayoutDelegate = viewController

        configureCollectionViewLayout(viewController)
        configureBackgroundColor(viewController)

        return viewController
    }

    // MARK: - Update UIViewController

    public func updateUIViewController(_ uiViewController: MessagesViewController, context: Context) {}

    // MARK: - UI Configuration

    public func configureBackgroundColor(_ viewController: MessagesViewController) {
        viewController.messagesCollectionView.backgroundColor = .background
        viewController.messagesCollectionView.backgroundView?.backgroundColor = .background
        viewController.view.backgroundColor = .background
    }

    private func configureCollectionViewLayout(_ viewController: MessagesViewController) {
        guard let layout = viewController.messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout else { return }

        layout.attributedTextMessageSizeCalculator.outgoingAvatarSize = .zero
        layout.audioMessageSizeCalculator.outgoingAvatarSize = .zero
        layout.textMessageSizeCalculator.outgoingAvatarSize = .zero

        typealias Floats = AppConstants.CGFloats.ChatPageView

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
}
