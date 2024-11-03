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

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService

    // MARK: - Properties

    public private(set) var selectedMessageID: String?

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

    public func addContextMenuInteractionToVisibleCellsOnce() {
        Task { @MainActor in
            addContextMenuInteractionToVisibleCells()
        }
    }

    public func startAddingContextMenuInteractionToVisibleCells() {
        contextMenuInteractionTimer = .scheduledTimer(
            timeInterval: 0.1,
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

    // MARK: - React to Selected Message

    @objc
    public func reactToSelectedMessage(_ sender: UIButton) {
        Task { @MainActor in
            guard let conversation = clientSession.conversation.currentConversation,
                  let message = conversation.messages?.first(where: { $0.id == selectedMessageID }),
                  let buttonText = sender.titleLabel?.text,
                  !buttonText.isBangQualifiedEmpty,
                  buttonText.components.count == 1,
                  let reactionStyle = Reaction.Style(emojiValue: buttonText),
                  let reaction = Reaction(reactionStyle) else { return }

            if let exception = await clientSession.reaction.react(reaction, to: message) {
                Logger.log(exception, with: .toast())
            }

            guard conversation.messages?.last?.id == message.id else { return }
            viewController.messagesCollectionView.scrollToLastItem()
        }
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

        for cell in visibleCells {
            guard let indexPath = viewController.messagesCollectionView.indexPath(for: cell),
                  let message = clientSession.conversation.currentConversation?.messages?.itemAt(indexPath.section),
                  cell.contextMenuMessageID != message.id,
                  !message.isMock,
                  !messageDeliveryService.isSendingMessage else { continue }

            cell.contextMenuMessageID = message.id
            var menuElements = [MenuElement]()

            let viewAlternateAction: MenuElement = .init(
                title: "View Alternate",
                image: .init(systemName: "arrow.left.arrow.right.square"),
                attributes: .default,
                handler: { _ in
                    self.chatPageViewService.alternateMessage?.toggle(.alternateText, for: cell)
                }
            )

            menuElements.append(viewAlternateAction)

            let reactionsViewController = ReactionsViewController()
            let menu: Menu = .init(children: menuElements)

            // NIT: I wonder if not removing the interaction is affecting performance.
            // The cell SHOULD be deallocated by the system eventually anyway, but...?
            cell.messageContainerView.addInteraction(
                targetedPreviewProvider: { _ in nil },
                menuConfigurationProvider: { _ in
                    reactionsViewController.deselectAllReactions()
                    Task.delayed(by: .milliseconds(10)) { @MainActor in
                        self.triggerExistingSelection(reactionsViewController)
                    }

                    return ContextMenuConfiguration(
                        accessoryView: reactionsViewController.view,
                        menu: menu
                    )
                },
                style: contextMenuStyle,
                onInteractionBegan: { self.selectedMessageID = message.id },
                onInteractionEnded: { self.selectedMessageID = nil }
            )
        }
    }

    @MainActor
    private func triggerExistingSelection(_ viewController: ReactionsViewController) {
        @Persistent(.currentUserID) var currentUserID: String?
        guard let messages = clientSession.conversation.currentConversation?.messages,
              let reactions = messages.first(where: { $0.id == selectedMessageID })?.reactions,
              let reactionEmojiValue = reactions.first(where: { $0.userID == currentUserID })?.style.emojiValue else { return }
        viewController.markSelected(reactionEmojiValue)
    }
}
