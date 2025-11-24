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

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import MessageKit

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

    // MARK: - UICollectionView

    override public func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let dataSource = messagesCollectionView.messagesDataSource else { return .init() }
        guard !isSectionReservedForTypingIndicator(indexPath.section) else {
            return super.collectionView(
                collectionView,
                cellForItemAt: indexPath
            )
        }

        let message = dataSource.messageForItem(
            at: indexPath,
            in: messagesCollectionView
        )

        if case .custom = message.kind {
            let systemMessageCell = messagesCollectionView.dequeueReusableCell(
                SystemMessageCell.self,
                for: indexPath
            )

            systemMessageCell.configure(
                with: message,
                at: indexPath,
                and: messagesCollectionView
            )

            return systemMessageCell
        }

        return super.collectionView(collectionView, cellForItemAt: indexPath)
    }

    // MARK: - UIScrollView

    override public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        viewService.onScrollViewDidEndDecelerating(scrollView)
    }

    override public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        viewService.onScrollViewDidEndScrollingAnimation()
    }

    override public func scrollViewDidScrollToTop(_: UIScrollView) {
        viewService.onScrollViewDidScrollToTop()
    }

    // MARK: - UITraitCollection

    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        viewService.onTraitCollectionDidChange(previousTraitCollection)
    }
}
