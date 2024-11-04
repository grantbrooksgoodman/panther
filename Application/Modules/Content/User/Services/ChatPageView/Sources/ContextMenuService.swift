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
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.ContextMenu

    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.commonServices.haptics) private var hapticsService: HapticsService
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService

    // MARK: - Properties

    private let viewController: ChatPageViewController

    private var contextMenuInteractionTimer: Timer?
    private var selectedMessageID: String?

    // MARK: - Object Lifecycle

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    deinit {
        contextMenuInteractionTimer?.invalidate()
        contextMenuInteractionTimer = nil
    }

    // MARK: - Configure Double Tap Gesture Recognizer

    public func configureDoubleTapGestureRecognizer() {
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(reactToSelectedMessage(_:)))
        doubleTapGesture.delaysTouchesBegan = true
        doubleTapGesture.numberOfTapsRequired = 2
        viewController.messagesCollectionView.addOrEnable(doubleTapGesture)
    }

    // MARK: - Context Menu Interaction Timer

    public func addContextMenuInteractionToVisibleCellsOnce() {
        Task { @MainActor in
            addContextMenuInteractionToVisibleCells()
        }
    }

    public func startAddingContextMenuInteractionToVisibleCells() {
        contextMenuInteractionTimer = .scheduledTimer(
            timeInterval: Floats.interactionTimerTimeInterval,
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
    public func reactToSelectedMessage(_ sender: Any) {
        guard let conversation = viewController.currentConversation else { return }
        func scrollToLastItemIfNeeded(_ message: Message) {
            guard conversation.messages?.last?.id == message.id else { return }
            viewController.messagesCollectionView.scrollToLastItem()
        }

        if let message = conversation.messages?.first(where: { $0.id == selectedMessageID }),
           let buttonText = (sender as? UIButton)?.titleLabel?.text,
           !buttonText.isBangQualifiedEmpty,
           buttonText.components.count == 1,
           let reactionStyle = Reaction.Style(emojiValue: buttonText),
           let reaction = Reaction(reactionStyle) {
            Task {
                if let exception = await clientSession.reaction.react(reaction, to: message) {
                    Logger.log(exception, with: .toast())
                }

                scrollToLastItemIfNeeded(message)
            }
        } else if let gestureRecognizer = sender as? UITapGestureRecognizer {
            let touchPoint = gestureRecognizer.location(in: viewController.messagesCollectionView)

            guard let indexPath = viewController.messagesCollectionView.indexPathForItem(at: touchPoint),
                  let selectedCell = viewController.messagesCollectionView.cellForItem(at: indexPath) as? MessageContentCell,
                  let message = viewController.currentConversation?.messages?.itemAt(indexPath.section) else { return }

            let convertedTouchPoint = viewController.messagesCollectionView.convert(touchPoint, to: selectedCell.messageContainerView)
            guard selectedCell.messageContainerView.bounds.contains(convertedTouchPoint) else { return }
            hapticsService.generateFeedback(.heavy)

            Task {
                if let reaction = Reaction(.love),
                   let exception = await self.clientSession.reaction.react(reaction, to: message) {
                    Logger.log(exception, with: .toast())
                }

                scrollToLastItemIfNeeded(message)
            }
        }
    }

    // MARK: - Auxiliary

    @objc
    private func addContextMenuInteractionToVisibleCells() {
        let visibleCells = viewController.messagesCollectionView.visibleCells.compactMap { $0 as? MessageContentCell }
        let contextMenuStyle: ContextMenuStyle = .init(preview: .init(
            transform: .init(
                scaleX: Floats.menuStyleTransformScaleX,
                y: Floats.menuStyleTransformScaleY
            ),
            topMargin: Floats.menuStyleTopMargin,
            bottomMargin: Floats.menuStyleBottomMargin,
            shadow: .init()
        ))

        for cell in visibleCells {
            guard let indexPath = viewController.messagesCollectionView.indexPath(for: cell),
                  let message = viewController.currentConversation?.messages?.itemAt(indexPath.section),
                  cell.contextMenuMessageID != message.id,
                  !message.isMock,
                  !messageDeliveryService.isSendingMessage else { continue }

            cell.contextMenuMessageID = message.id
            var menuElements = [MenuElement]()

            // FIXME: Test/scaffolding code.
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
                    Task.delayed(by: .milliseconds(Floats.triggerExistingSelectionDelayMilliseconds)) { @MainActor in
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
        guard let messages = self.viewController.currentConversation?.messages,
              let reactions = messages.first(where: { $0.id == selectedMessageID })?.reactions,
              let reactionEmojiValue = reactions.first(where: { $0.userID == currentUserID })?.style.emojiValue else { return }
        viewController.markSelected(reactionEmojiValue)
    }
}
