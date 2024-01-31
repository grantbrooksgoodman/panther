//
//  ChatPageViewController+MessagesLayoutDelegate.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 30/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import MessageKit

extension ChatPageViewController: MessagesLayoutDelegate {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatPageView

    // MARK: - Cell Bottom Label Height

    public func cellBottomLabelHeight(
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) -> CGFloat {
        guard let messages = conversation?.messages,
              messages.count > indexPath.section else { return 0 }
        return indexPath.section == messages.count - 1 ? Floats.layoutDelegateCellBottomLabelHeight : 0
    }

    // MARK: - Cell Top Label Height

    public func cellTopLabelHeight(
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) -> CGFloat {
        guard indexPath.section != 0 else { return Floats.layoutDelegateCellTopLabelHeight }

        guard let messages = conversation?.messages,
              let message = message as? Message,
              messages.count > indexPath.section,
              indexPath.section - 1 > -1 else { return 0 }

        let previousSentDate = messages[indexPath.section - 1].sentDate // TODO: Audit this.
        guard message.sentDate.seconds(from: previousSentDate) > Int(Floats.layoutDelegateCellTopLabelHeightSentDateSecondsComparator) else { return 0 }
        return Floats.layoutDelegateCellTopLabelHeight
    }

    // MARK: - Message Top Label Height

    public func messageTopLabelHeight(
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) -> CGFloat {
        guard let conversation,
              conversation.participants.count > 2,
              let messages = conversation.messages,
              let message = message as? Message else { return 0 }

        if messages.count > indexPath.section,
           indexPath.section - 1 > -1,
           messages[indexPath.section - 1].fromAccountID == message.fromAccountID {
            return 0
        }

        return message.isFromCurrentUser ? 0 : Floats.layoutDelegateMessageTopLabelHeight
    }
}
