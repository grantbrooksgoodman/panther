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

final class ChatPageViewController: MessagesViewController {
    // MARK: - Dependencies

    @Dependency(\.clientSession.conversation.currentConversation) var currentConversation: Conversation?

    @Dependency(\.chatPageViewService) private var viewService: ChatPageViewService

    // MARK: - Init

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewService.onViewWillAppear()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewService.onViewDidAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewService.onViewWillDisappear()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewService.onViewDidDisappear()
    }

    // MARK: - UICollectionView

    override func collectionView(
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

    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        viewService.onScrollViewDidEndDecelerating(scrollView)
    }

    override func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        viewService.onScrollViewDidEndScrollingAnimation()
    }

    override func scrollViewDidScrollToTop(_: UIScrollView) {
        viewService.onScrollViewDidScrollToTop()
    }

    // MARK: - UITraitCollection

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        viewService.onTraitCollectionDidChange(previousTraitCollection)
    }
}
