//
//  ChatPageViewController.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 30/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import MessageKit
import Redux

public final class ChatPageViewController: MessagesViewController {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatPageView

    // MARK: - Dependencies

    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.clientSession.conversation.currentConversation) private var currentConversation: Conversation?
    @Dependency(\.inputBarAccessoryViewService) private var inputBarAccessoryViewService: InputBarAccessoryViewService
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    /// A convenience property linked to the client session's `currentConversation` value.
    public var conversation: Conversation? { currentConversation }

    private var typingIndicatorTimer: Timer?

    // MARK: - Init

    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Lifecycle

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        toggleBuildInfoOverlay(on: false)
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        chatPageState.setIsPresented(true)
        messagesCollectionView.scrollToLastItem(animated: true)
        typingIndicatorTimer = .scheduledTimer(
            timeInterval: .init(Floats.typingIndicatorTimerTimeInterval),
            target: self,
            selector: #selector(toggleTypingIndicator),
            userInfo: nil,
            repeats: true
        )
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        @Persistent(.hidesBuildInfoOverlay) var hidesBuildInfoOverlay: Bool?
        toggleBuildInfoOverlay(on: !(hidesBuildInfoOverlay ?? false))

        typingIndicatorTimer?.invalidate()
        typingIndicatorTimer = nil
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        chatPageState.setIsPresented(false)
        Task {
            if let exception = await inputBarAccessoryViewService.textViewDidChange(to: "") {
                Logger.log(exception, with: .toast())
            }
        }
    }

    // MARK: - UICollectionView

    override public func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        if let typingIndicatorCell = super.collectionView(collectionView, cellForItemAt: indexPath) as? TypingIndicatorCell {
            return typingIndicatorCell
        }

        guard let genericCell = super.collectionView(collectionView, cellForItemAt: indexPath) as? MessageCollectionViewCell else { return .init() }
        genericCell.tag = indexPath.section

        guard let textCell = genericCell as? TextMessageCell,
              let messages = conversation?.messages,
              messages.count > indexPath.section else { return genericCell }

        let currentMessage = messages[indexPath.section]

        if !ThemeService.isDefaultThemeApplied /* , */
        /*! currentMessage.isDisplayingAlternate */ {
            if currentMessage.isFromCurrentUser {
                textCell.messageLabel.textInsets.right = Floats.textCellMessageLabelRightTextInset
            } else {
                textCell.messageLabel.textInsets.left = Floats.textCellMessageLabelLeftTextInset
            }
        }

//        guard currentMessage.isDisplayingAlternate else { return textCell }
//        textCell.messageLabel.font = textCell.messageLabel.font.withTraits(traits: .traitItalic)
//
//        guard textCell.messageLabel.maxNumberOfLines <= 1 else { return textCell }
//        textCell.messageContainerView.frame.size.width = textCell.messageLabel.intrinsicContentSize.width
//        textCell.messageLabel.frame.size.width = textCell.messageLabel.intrinsicContentSize.width

        return textCell
    }

    // MARK: - Auxiliary

    private func toggleBuildInfoOverlay(on: Bool) {
        guard let overlayWindow = uiApplication.keyWindow?.firstSubview(for: "BUILD_INFO_OVERLAY_WINDOW") as? UIWindow else { return }
        overlayWindow.isHidden = !on
    }

    @objc
    private func toggleTypingIndicator() {
        @Persistent(.currentUserID) var currentUserID: String?
        guard let conversation,
              conversation.participants.filter({ $0.userID != currentUserID }).contains(where: { $0.isTyping }) else {
            guard !isTypingIndicatorHidden else { return }
            setTypingIndicatorViewHidden(true, animated: true)
            return
        }

        guard isTypingIndicatorHidden else { return }
        setTypingIndicatorViewHidden(false, animated: true)
        messagesCollectionView.scrollToLastItem(animated: true)
    }
}
