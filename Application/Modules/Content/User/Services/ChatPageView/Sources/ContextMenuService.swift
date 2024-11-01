//
//  ContextMenuService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 30/10/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import ContextualMenu
import MessageKit

public final class ContextMenuService {
    // MARK: - Dependencies

    @Dependency(\.chatPageViewService.alternateMessage) private var alternateMessageService: AlternateMessageService?
    @Dependency(\.clientSession.conversation.fullConversation) private var fullConversation: Conversation?
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService

    // MARK: - Properties

    private let viewController: ChatPageViewController

    private var contextMenuInteractionTimer: Timer?

    // MARK: - Object Lifecycle

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    deinit {
        contextMenuInteractionTimer?.invalidate()
        contextMenuInteractionTimer = nil
    }

    // MARK: - Context Menu Interaction Timer

    public func startAddingContextMenuInteractionToVisibleCells() {
        contextMenuInteractionTimer = .scheduledTimer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(addContextMenuInteractionToVisibleCells),
            userInfo: nil,
            repeats: true
        )
    }

    public func stopAddingContextMenuInteractionToVisibleCells() {
        contextMenuInteractionTimer?.invalidate()
        contextMenuInteractionTimer = nil
    }

    // MARK: - Auxiliary

    @objc
    private func addContextMenuInteractionToVisibleCells() { // FIXME: Test/scaffolding code.
        let visibleCells = viewController.messagesCollectionView.visibleCells.compactMap { $0 as? MessageContentCell }
        let contextMenuStyle: ContextMenuStyle = .init(preview: .init(
            transform: .init(scaleX: 1.08, y: 1.08),
            topMargin: 8,
            bottomMargin: 8,
            shadow: .init()
        ))

        let reactionsViewController = ReactionsViewController()
        for cell in visibleCells where !cell.hasContextMenuInteraction {
            guard let indexPath = viewController.messagesCollectionView.indexPath(for: cell),
                  let message = fullConversation?.messages?.itemAt(indexPath.section),
                  !message.isMock,
                  !messageDeliveryService.isSendingMessage else { continue }

            let menu: Menu = .init(children: [.init(
                title: "View Alternate",
                image: .init(systemName: "arrow.left.arrow.right.square"),
                attributes: .default,
                handler: { _ in
                    self.alternateMessageService?.toggle(.alternateText, for: cell)
                }
            )])

            cell.messageContainerView.addInteraction(
                targetedPreviewProvider: { _ in nil },
                menuConfigurationProvider: { _ in
                    ContextMenuConfiguration(
                        accessoryView: reactionsViewController.view,
                        menu: menu
                    )
                },
                style: contextMenuStyle
            )
        }
    }
}
