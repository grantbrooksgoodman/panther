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

    // MARK: - Properties

    public var conversation: Conversation? {
        @Dependency(\.clientSession.conversation.currentConversation) var currentConversation: Conversation?
        return currentConversation
    }

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

        messagesCollectionView.scrollToLastItem(animated: true)
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        @Persistent(.hidesBuildInfoOverlay) var hidesBuildInfoOverlay: Bool?
        toggleBuildInfoOverlay(on: !(hidesBuildInfoOverlay ?? false))
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
        @Dependency(\.uiApplication) var uiApplication: UIApplication
        guard let overlayWindow = uiApplication.keyWindow?.firstSubview(for: "BUILD_INFO_OVERLAY_WINDOW") as? UIWindow else { return }
        guard on else {
            overlayWindow.isHidden = true
            DevModeService.removeAction(withTitle: "Show/Hide Build Info Overlay")
            return
        }

        overlayWindow.isHidden = false
        DevModeService.addStandardActions()
    }
}
