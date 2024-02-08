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
    // MARK: - Dependencies

    @Dependency(\.clientSession.conversation.currentConversation) public var currentConversation: Conversation?

    @Dependency(\.chatPageViewService) private var viewService: ChatPageViewService

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
        viewService.onViewWillAppear()
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewService.onViewDidAppear()
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewService.onViewWillDisappear()
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewService.onViewDidDisappear()
    }

    // MARK: - UIScrollView

    override public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        viewService.onScrollViewDidEndDecelerating(scrollView)
    }

    override public func scrollViewDidScrollToTop(_: UIScrollView) {
        viewService.onScrollViewDidScrollToTop()
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
              let messages = currentConversation?.messages,
              messages.count > indexPath.section else { return genericCell }

        let currentMessage = messages[indexPath.section]

        if !ThemeService.isDefaultThemeApplied /* , */
        /*! currentMessage.isDisplayingAlternate */ {
            typealias Floats = AppConstants.CGFloats.ChatPageView
            if currentMessage.isFromCurrentUser {
                textCell.messageLabel.textInsets.right = Floats.textCellMessageLabelRightTextInset
            } else {
                textCell.messageLabel.textInsets.left = Floats.textCellMessageLabelLeftTextInset
            }
        }

        return textCell
    }

    // MARK: - UITraitCollection

    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        viewService.onTraitCollectionDidChange(previousTraitCollection)
    }
}
