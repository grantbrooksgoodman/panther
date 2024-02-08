//
//  AlternateMessageService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 08/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import MessageKit
import Redux

public final class AlternateMessageService {
    // MARK: - Properties

    private let viewController: ChatPageViewController

    private var alternateMessageIDs = [String]()

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Is Displaying Alternate

    public func isDisplayingAlternate(for message: Message) -> Bool {
        alternateMessageIDs.contains(message.id)
    }

    // MARK: - Restore All Alternates

    public func restoreAllAlternates() {
        alternateMessageIDs = []
    }

    // MARK: - Toggle Alternate

    public func toggleAlternate(for cell: MessageContentCell) {
        guard let indexPath = viewController.messagesCollectionView.indexPath(for: cell),
              let messages = viewController.currentConversation?.messages,
              messages.count > indexPath.section else { return }
        let message = messages[indexPath.section]

        defer { viewController.messagesCollectionView.reloadItems(at: [indexPath]) }

        guard !alternateMessageIDs.contains(message.id) else {
            alternateMessageIDs.removeAll(where: { $0 == message.id })
            return
        }

        alternateMessageIDs.append(message.id)
    }
}
