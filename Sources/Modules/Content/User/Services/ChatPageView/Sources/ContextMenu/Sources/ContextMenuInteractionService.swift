//
//  ContextMenuInteractionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/11/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import MessageKit

// swiftlint:disable:next type_body_length
public final class ContextMenuInteractionService {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.ContextMenu

    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.coreKit.gcd) private var coreGCD: CoreKit.GCD
    @Dependency(\.commonServices.haptics) private var hapticsService: HapticsService
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService
    @Dependency(\.notificationCenter) private var notificationCenter: NotificationCenter
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    // Bool
    public private(set) var isPresentingContextMenu = false {
        didSet { restoreSpeakingCellAttributes() }
    }

    private var hadFirstResponderBeforeInteraction = false
    private var lastMessageWasVisibleBeforeInteraction = false

    // Other
    public private(set) var selectedMessageID: String?

    private let viewController: ChatPageViewController

    private var contextMenuInteractionTimer: Timer?
    private var scrollViewMaxContentOffsetY: CGFloat = 0

    // MARK: - Computed Properties

    @MainActor
    private var isLastMessageVisible: Bool {
        let lastVisibleMessageID = viewController
            .messagesCollectionView
            .visibleCells
            .filter { $0.indexPath != nil }
            .sorted(by: { $0.indexPath! < $1.indexPath! })
            .compactMap { ($0 as? MessageContentCell)?.contextMenuMessageID }
            .last

        // Leeway/margin of error for scroll position
        // swiftlint:disable:next line_length
        let lowerOffsetRange = (scrollViewMaxContentOffsetY - Floats.isLastMessageVisibleScrollViewOffsetLowerBoundDecrement) ... (scrollViewMaxContentOffsetY - 1) // swiftlint:disable:next line_length
        let upperOffsetRange = (scrollViewMaxContentOffsetY + 1) ... (scrollViewMaxContentOffsetY + Floats.isLastMessageVisibleScrollViewOffsetUpperBoundIncrement)

        guard let lastVisibleMessageID,
              let lastMessageID = viewController.currentConversation?.messages?.last?.id,
              lastVisibleMessageID == lastMessageID,
              lowerOffsetRange.contains(viewController.messagesCollectionView.contentOffset.y) ||
              upperOffsetRange.contains(viewController.messagesCollectionView.contentOffset.y) ||
              viewController.messagesCollectionView.contentOffset.y == scrollViewMaxContentOffsetY else { return false }

        return true
    }

    // MARK: - Object Lifecycle

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    deinit {
        contextMenuInteractionTimer?.invalidate()
        contextMenuInteractionTimer = nil
        removeKeyboardWillShowObserver()
    }

    // MARK: - Configure Double Tap Gesture Recognizer

    public func configureDoubleTapGestureRecognizer() {
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(reactToSelectedMessage(_:)))
        doubleTapGesture.delaysTouchesBegan = true
        doubleTapGesture.numberOfTapsRequired = Int(Floats.doubleTapGestureNumberOfTapsRequired)
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

    // MARK: - Remove UIMenu Long Press Gesture for Visible Cells

    public func removeUIMenuLongPressGestureForVisibleCells() {
        Task { @MainActor in
            let visibleCells = viewController.messagesCollectionView.visibleCells.compactMap { $0 as? MessageContentCell }
            for cell in visibleCells {
                // Remove default UIMenu long press gesture recognizer
                cell.contentView
                    .gestureRecognizers?
                    .removeAll(where: {
                        ($0 as? UILongPressGestureRecognizer)?.minimumPressDuration == Floats.longPressGestureMinimumPressDuration
                    })
            }
        }
    }

    // MARK: - React to Selected Message

    @objc
    public func reactToSelectedMessage(_ sender: Any) {
        guard !clientSession.reaction.isReactingToMessage else {
            clientSession.reaction.addEffectUponIsReactingToMessage(
                changedTo: false,
                id: .init("\(Int.random(in: 1 ... 1_000_000))")
            ) { self.reactToSelectedMessage(sender) }
            return
        }

        guard let conversation = viewController.currentConversation else { return }
        func scrollToLastItemIfNeeded(_ message: Message) {
            func scrollToLastItem() {
                Task.delayed(by: .milliseconds(Floats.reactionScrollToLastItemDelayMilliseconds)) { @MainActor in
                    self.viewController.messagesCollectionView.scrollToLastItem()
                }
            }

            guard conversation.messages?.last?.id == message.id else { return }
            guard clientSession.reaction.isReactingToMessage else { return scrollToLastItem() }
            clientSession.reaction.addEffectUponIsReactingToMessage(changedTo: false, id: .scrollToLastItem) { scrollToLastItem() }
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
                  let message = viewController.currentConversation?.messages?.itemAt(indexPath.section),
                  !message.isConsentMessage else { return }

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

    // MARK: - Keyboard Will Show Observer

    public func addKeyboardWillShowObserver() {
        notificationCenter.addObserver(
            self,
            name: UIResponder.keyboardWillShowNotification
        ) { notification in
            guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
            self.scrollViewMaxContentOffsetY = self.viewController.messagesCollectionView.maxContentOffsetY + keyboardFrame.cgRectValue.height
        }
    }

    public func removeKeyboardWillShowObserver() {
        notificationCenter.removeObserver(
            self,
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
    }

    // MARK: - Set Is Presenting Context Menu

    public func setIsPresentingContextMenu(_ isPresentingContextMenu: Bool) {
        self.isPresentingContextMenu = isPresentingContextMenu
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
            defer {
                // Remove default UIMenu long press gesture recognizer
                cell.contentView
                    .gestureRecognizers?
                    .removeAll(where: {
                        ($0 as? UILongPressGestureRecognizer)?.minimumPressDuration == Floats.longPressGestureMinimumPressDuration
                    })
            }

            guard ContextMenuInteraction.canBegin,
                  let indexPath = viewController.messagesCollectionView.indexPath(for: cell),
                  let message = viewController.currentConversation?.messages?.itemAt(indexPath.section),
                  cell.contextMenuMessageID != message.id,
                  !message.isMock,
                  !messageDeliveryService.isSendingMessage else { continue }

            cell.contextMenuMessageID = message.id
            let reactionsViewController = ReactionsViewController()

            // NIT: I wonder if not removing the interaction is affecting performance.
            // The cell SHOULD be deallocated by the system eventually anyway, but...?
            cell.messageContainerView.addInteraction(
                targetedPreviewProvider: { _ in nil },
                menuConfigurationProvider: { _ in
                    let menu = self.chatPageViewService.contextMenu?.actionHandler.menuForMessage(message) ?? .init(children: [])
                    reactionsViewController.deselectAllReactions()
                    Task.delayed(by: .milliseconds(Floats.triggerExistingSelectionDelayMilliseconds)) { @MainActor in
                        self.triggerExistingSelection(reactionsViewController)
                        reactionsViewController.view.alpha = message.isConsentMessage ? 0 : 1
                    }

                    reactionsViewController.view.isUserInteractionEnabled = message.isConsentMessage ? false : true
                    return ContextMenuConfiguration(
                        accessoryView: reactionsViewController.view,
                        menu: menu
                    )
                },
                style: contextMenuStyle,
                onInteractionBegan: {
                    Task { @MainActor in
                        self.viewController.messagesCollectionView.isScrollEnabled = false
                        self.selectedMessageID = message.id

                        self.hadFirstResponderBeforeInteraction = self.uiApplication.firstResponder != nil
                        self.lastMessageWasVisibleBeforeInteraction = self.isLastMessageVisible
                    }
                },
                onInteractionEnded: {
                    Task { @MainActor in
                        /// - NOTE: Fixes a bug in which a dismissal of the context menu under the below conditions would cause the scroll view content offset to be set incorrectly.
                        @MainActor
                        func scrollToLastItemIfNeeded() {
                            defer {
                                self.hadFirstResponderBeforeInteraction = false
                                self.lastMessageWasVisibleBeforeInteraction = false
                            }

                            guard self.hadFirstResponderBeforeInteraction,
                                  self.lastMessageWasVisibleBeforeInteraction else { return }

                            Logger.log(
                                "Intercepted scroll view content offset bug.",
                                domain: .bugPrevention,
                                metadata: [self, #file, #function, #line]
                            )

                            self.coreGCD.after(.milliseconds(Floats.interactionScrollToLastItemDelayMilliseconds)) {
                                self.viewController.messagesCollectionView.scrollToLastItem(animated: false)
                            }
                        }

                        self.viewController.messagesCollectionView.isScrollEnabled = true
                        scrollToLastItemIfNeeded()
                    }
                }
            )

            // TODO: May not persist for new cell dequeues – audit this.
            if let audioMessagePlaybackService = chatPageViewService.audioMessagePlayback,
               let audioCell = cell as? AudioMessageCell {
                let singleTapGesture = UITapGestureRecognizer(
                    target: audioMessagePlaybackService,
                    action: #selector(audioMessagePlaybackService.didTapPlayButton(_:))
                )
                audioCell.playButton.addOrEnable(singleTapGesture)
            }
        }
    }

    fileprivate func indexPath(for cell: UICollectionViewCell) -> IndexPath? {
        viewController.messagesCollectionView.indexPath(for: cell)
    }

    private func restoreSpeakingCellAttributes() {
        guard let speakingCell = chatPageViewService.contextMenu?.actionHandler.speakingCell as? TextMessageCell,
              let speakingMessage = chatPageViewService.contextMenu?.actionHandler.speakingMessage,
              let labelText = speakingCell.messageLabel.text,
              let alternateMessageService = chatPageViewService.alternateMessage else { return }

        typealias Colors = AppConstants.Colors.UserContentExtensions.Message

        // swiftlint:disable line_length
        let nonCurrentUserForegroundColor = !Application.isInPrevaricationMode && ThemeService.isDarkModeActive ? Colors.kindAttributedTextDarkForeground : Colors.kindAttributedTextLightForeground
        let attributedStringForegroundColor = UIColor(speakingMessage.isFromCurrentUser ? Colors.kindAttributedTextCurrentUserForeground : nonCurrentUserForegroundColor)
        // swiftlint:enable line_length

        if alternateMessageService.isDisplayingAlternateText(for: speakingMessage) ||
            alternateMessageService.isDisplayingAudioTranscription(for: speakingMessage) {
            speakingCell.messageLabel.attributedText = .messageCellString(
                labelText,
                foregroundColor: attributedStringForegroundColor,
                italicized: true
            )
        } else {
            speakingCell.messageLabel.attributedText = .init(
                string: labelText,
                attributes: [
                    .foregroundColor: attributedStringForegroundColor,
                    .font: alternateMessageService.textCellLabelFont,
                ] as [NSAttributedString.Key: Any]
            )
        }
    }

    @MainActor
    private func triggerExistingSelection(_ viewController: ReactionsViewController) {
        @Persistent(.currentUserID) var currentUserID: String?
        guard let messages = self.viewController.currentConversation?.messages,
              let reactions = messages.first(where: { $0.id == selectedMessageID })?.reactions,
              let reactionStyle = reactions.first(where: { $0.userID == currentUserID })?.style else { return }
        viewController.markSelected(reactionStyle)
    }
}

private extension UICollectionViewCell {
    var indexPath: IndexPath? {
        @Dependency(\.chatPageViewService.contextMenu?.interaction) var contextMenuInteractionService: ContextMenuInteractionService?
        return contextMenuInteractionService?.indexPath(for: self)
    }
}

private extension UIScrollView {
    var maxContentOffsetY: CGFloat { contentSize.height - bounds.height + contentInset.bottom }
}
