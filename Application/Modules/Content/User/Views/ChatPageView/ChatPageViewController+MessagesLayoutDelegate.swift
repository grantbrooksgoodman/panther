//
//  ChatPageViewController+MessagesLayoutDelegate.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 30/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import MessageKit

extension ChatPageViewController: MessagesLayoutDelegate {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatPageView.MessagesLayoutDelegate

    // MARK: - Cell Bottom Label Height

    public func cellBottomLabelHeight(
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) -> CGFloat {
        @Dependency(\.chatPageViewService.alternateMessage) var alternateMessageService: AlternateMessageService?
        guard let currentConversation,
              let messages = currentConversation.messages,
              let message = message as? Message,
              !message.isMock else { return 0 }

        if let alternateMessageService,
           alternateMessageService.isDisplayingAlternateText(for: message) {
            return Floats.cellBottomLabelHeight
        } else if currentConversation.participants.count == 2,
                  indexPath.section == messages.count - 1,
                  message.isFromCurrentUser {
            return Floats.cellBottomLabelHeight
        } else if message.reactions != nil {
            return Floats.cellBottomLabelHeight
        }

        return 0
    }

    // MARK: - Cell Top Label Height

    public func cellTopLabelHeight(
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) -> CGFloat {
        guard indexPath.section != 0 else { return Floats.cellTopLabelHeight }

        guard let messages = currentConversation?.messages,
              let message = message as? Message,
              let previousSentDate = messages.itemAt(indexPath.section - 1)?.sentDate,
              message.sentDate.seconds(from: previousSentDate) > Int(Floats.cellTopLabelHeightSentDateSecondsComparator) else { return 0 }

        return Floats.cellTopLabelHeight
    }

    // MARK: - Message Top Label Height

    public func messageTopLabelHeight(
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) -> CGFloat {
        guard let currentConversation,
              currentConversation.participants.count > 2,
              let messages = currentConversation.messages,
              let message = message as? Message else { return 0 }

        if messages.itemAt(indexPath.section - 1)?.fromAccountID == message.fromAccountID {
            return 0
        }

        return message.isFromCurrentUser ? 0 : Floats.messageTopLabelHeight
    }
}
