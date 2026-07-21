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
import AlertKit
import AppSubsystem

/* 3rd-party */
import MessageKit

final class ChatPageViewController: MessagesViewController {
    // MARK: - Dependencies

    @Dependency(\.clientSession.entity.conversation.currentConversation) var currentConversation: Conversation?
    @Dependency(\.clientSession.entity.conversation.displayedMessages) var displayedMessages: [Message]

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.clientSession.outbox) private var messageOutboxService: MessageOutboxService
    @Dependency(\.chatPageViewService) private var viewService: ChatPageViewService

    // MARK: - Init

    override init(
        nibName nibNameOrNil: String?,
        bundle nibBundleOrNil: Bundle?
    ) {
        super.init(
            nibName: nibNameOrNil,
            bundle: nibBundleOrNil
        )
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

        let cell = super.collectionView(
            collectionView,
            cellForItemAt: indexPath
        )

        configureFailedIndicator(
            on: cell,
            for: message as? Message
        )

        return cell
    }

    // MARK: - UIScrollView

    override func scrollViewDidEndDecelerating(
        _ scrollView: UIScrollView
    ) {
        viewService.onScrollViewDidEndDecelerating(scrollView)
    }

    override func scrollViewDidEndScrollingAnimation(
        _ scrollView: UIScrollView
    ) {
        viewService.onScrollViewDidEndScrollingAnimation()
    }

    override func scrollViewDidScrollToTop(
        _: UIScrollView
    ) {
        viewService.onScrollViewDidScrollToTop()
    }

    // MARK: - UITraitCollection

    override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        viewService.onTraitCollectionDidChange(previousTraitCollection)
    }

    // MARK: - Present Failed Message Action Sheet

    func presentFailedMessageActionSheet(
        forMessageID messageID: String,
        sourceView: UIView
    ) {
        let messageOutboxService = LockIsolated(messageOutboxService)
        let deleteAction = AKAction(
            Localized(.delete).wrappedValue,
            style: .destructive
        ) {
            messageOutboxService.wrappedValue.remove(id: messageID)
        }

        let tryAgainAction = AKAction(Localized(.tryAgain).wrappedValue) {
            Task {
                await messageOutboxService.wrappedValue.retry(entryID: messageID)
            }
        }

        Task { @MainActor in
            await AKActionSheet(
                actions: [
                    .cancelAction,
                    deleteAction,
                    tryAgainAction,
                ],
                sourceItem: .custom(.view(sourceView))
            ).present(translating: [])
        }
    }

    // MARK: - Auxiliary

    private func configureFailedIndicator(
        on cell: UICollectionViewCell,
        for message: Message?
    ) {
        typealias Floats = AppConstants.CGFloats.ChatPageView.FailedOutboxIndicator
        typealias Strings = AppConstants.Strings.ChatPageView.FailedOutboxIndicator

        guard let contentCell = cell as? MessageContentCell else { return }
        let existingButton = contentCell.contentView.firstSubview(
            for: Strings.indicatorButtonSemanticTag
        ) as? UIButton

        guard let message,
              message.isFailedOutboxMessage else {
            existingButton?.removeFromSuperview()
            return
        }

        if let existingButton {
            existingButton.isHidden = false
            return
        }

        let indicatorButton = UIButton(type: .system)
        indicatorButton.setImage(
            UIImage(systemName: Strings.buttonImageSystemName),
            for: .normal
        )

        indicatorButton.tag = coreUI.semTag(
            for: Strings.indicatorButtonSemanticTag
        )

        indicatorButton.tintColor = .systemRed
        indicatorButton.translatesAutoresizingMaskIntoConstraints = false

        indicatorButton.addTarget(
            self,
            action: #selector(failedIndicatorTapped(_:)),
            for: .touchUpInside
        )

        contentCell.contentView.addSubview(indicatorButton)
        NSLayoutConstraint.activate([
            indicatorButton.widthAnchor.constraint(
                equalToConstant: Floats.indicatorButtonSize
            ),
            indicatorButton.heightAnchor.constraint(
                equalToConstant: Floats.indicatorButtonSize
            ),
            indicatorButton.centerYAnchor.constraint(
                equalTo: contentCell.messageContainerView.centerYAnchor
            ),
            indicatorButton.leadingAnchor.constraint(
                equalTo: contentCell.messageContainerView.trailingAnchor,
                constant: Floats.indicatorButtonSpacing
            ),
        ])
    }

    @objc
    private func failedIndicatorTapped(_ sender: UIButton) {
        guard let cell = sender.superview?.superview as? MessageContentCell,
              let indexPath = messagesCollectionView.indexPath(for: cell),
              let message = displayedMessages.itemAt(indexPath.section),
              message.isFailedOutboxMessage else { return }

        presentFailedMessageActionSheet(
            forMessageID: message.id,
            sourceView: sender
        )
    }
}
