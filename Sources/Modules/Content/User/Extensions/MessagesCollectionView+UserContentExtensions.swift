//
//  MessagesCollectionView+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/07/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import MessageKit

extension MessagesCollectionView {
    func scrollTo(
        messageID: String,
        at scrollPosition: UICollectionView.ScrollPosition = .top,
        animated: Bool = true
    ) {
        @Dependency(\.clientSession.conversation.currentConversation?.messages) var messages: [Message]?
        guard let messageIndex = messages?.firstIndex(where: { $0.id == messageID }),
              messageIndex < numberOfSections,
              numberOfItems(inSection: messageIndex) > 0 else { return }

        scrollToItem(
            at: .init(item: 0, section: messageIndex),
            at: scrollPosition,
            animated: animated
        )
    }
}
