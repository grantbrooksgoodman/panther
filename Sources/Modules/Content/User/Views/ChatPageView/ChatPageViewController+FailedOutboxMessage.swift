//
//  ChatPageViewController+FailedOutboxMessage.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem

/* 3rd-party */
import MessageKit

extension ChatPageViewController {
    // MARK: - Types

    // TODO: Absorb into AppConstants.
    private enum FailedIndicator {
        static let buttonSize: CGFloat = 22
        static let leadingSpacing: CGFloat = 6
        static let tag = 9801
    }

    // MARK: - Configure Failed Indicator

    func configureFailedIndicator(
        on cell: UICollectionViewCell,
        for message: Message?
    ) {
        guard let contentCell = cell as? MessageContentCell else { return }
        let existingButton = contentCell.contentView.viewWithTag(FailedIndicator.tag) as? UIButton

        guard let message, message.isFailedOutboxMessage else {
            existingButton?.removeFromSuperview()
            return
        }

        if let existingButton {
            existingButton.isHidden = false
            return
        }

        let button = UIButton(type: .system)
        button.setImage( // TODO: Needs a constant.
            UIImage(systemName: "exclamationmark.circle"),
            for: .normal
        )

        button.tag = FailedIndicator.tag
        button.tintColor = .systemRed
        button.translatesAutoresizingMaskIntoConstraints = false

        button.addTarget(
            self,
            action: #selector(failedIndicatorTapped(_:)),
            for: .touchUpInside
        )

        contentCell.contentView.addSubview(button)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: FailedIndicator.buttonSize),
            button.heightAnchor.constraint(equalToConstant: FailedIndicator.buttonSize),
            button.centerYAnchor.constraint(equalTo: contentCell.messageContainerView.centerYAnchor),
            button.leadingAnchor.constraint(
                equalTo: contentCell.messageContainerView.trailingAnchor,
                constant: FailedIndicator.leadingSpacing
            ),
        ])
    }

    // MARK: - Failed Indicator Tapped

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

    // MARK: - Present Failed Message Action Sheet

    func presentFailedMessageActionSheet(
        forMessageID messageID: String,
        sourceView: UIView
    ) { // swiftlint:disable:next identifier_name
        @Dependency(\.clientSession.outbox) var _outbox: MessageOutboxService
        let outbox = LockIsolated(_outbox)

        let tryAgainAction = AKAction(Localized(.tryAgain).wrappedValue) {
            Task {
                await outbox.wrappedValue.retry(entryID: messageID)
            }
        }

        let deleteAction = AKAction(
            Localized(.delete).wrappedValue,
            style: .destructive
        ) {
            outbox.wrappedValue.remove(id: messageID)
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
}
