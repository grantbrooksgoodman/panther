//
//  MessageFlowLayout.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/11/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import MessageKit

/// The collection view flow layout for the chat page's message list.
///
/// ``MessageFlowLayout`` extends the standard message layout with sizing for system message
/// cells and extra trailing padding for failed outbox messages.
@MainActor
final class MessageFlowLayout: @MainActor MessagesCollectionViewFlowLayout {
    // MARK: - Properties

    /// The extra trailing padding added to the message container of failed outbox messages,
    /// reserving space for the failure indicator button.
    static let failedIndicatorPaddingRight: CGFloat = 28

    private lazy var sizeCalculator = SizeCalculator(layout: self)

    // MARK: - Methods

    /// Returns the size calculator for the item at the given index path, substituting the
    /// system message calculator for custom-kind messages.
    override func cellSizeCalculatorForItem(
        at indexPath: IndexPath
    ) -> CellSizeCalculator {
        if isSectionReservedForTypingIndicator(indexPath.section) {
            return typingIndicatorSizeCalculator
        }

        let message = messagesDataSource.messageForItem(at: indexPath, in: messagesCollectionView)
        if case .custom = message.kind {
            return sizeCalculator
        }

        return super.cellSizeCalculatorForItem(at: indexPath)
    }

    /// Returns the layout attributes for the elements in the given rectangle, applying
    /// failed-outbox padding where needed.
    override func layoutAttributesForElements(
        in rect: CGRect
    ) -> [UICollectionViewLayoutAttributes]? {
        guard let attributes = super.layoutAttributesForElements(in: rect) else { return nil }
        for attribute in attributes {
            applyFailedOutboxPaddingIfNeeded(to: attribute)
        }

        return attributes
    }

    /// Returns the layout attributes for the item at the given index path, applying
    /// failed-outbox padding where needed.
    override func layoutAttributesForItem(
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        guard let attributes = super.layoutAttributesForItem(at: indexPath) else { return nil }
        applyFailedOutboxPaddingIfNeeded(to: attributes)
        return attributes
    }

    /// Returns the standard message size calculators plus the system message calculator.
    override func messageSizeCalculators() -> [MessageSizeCalculator] {
        var superCalculators = super.messageSizeCalculators()
        superCalculators.append(sizeCalculator)
        return superCalculators
    }

    // MARK: - Auxiliary

    private func applyFailedOutboxPaddingIfNeeded(
        to attributes: UICollectionViewLayoutAttributes
    ) {
        guard let msgAttributes = attributes as? MessagesCollectionViewLayoutAttributes else { return }

        let message = messagesDataSource.messageForItem(
            at: attributes.indexPath,
            in: messagesCollectionView
        )

        guard let message = message as? Message,
              message.isFailedOutboxMessage else { return }

        msgAttributes.messageContainerPadding.right += Self.failedIndicatorPaddingRight
    }
}

@MainActor
private final class SizeCalculator: @MainActor MessageSizeCalculator {
    // MARK: - Init

    override init(layout: MessagesCollectionViewFlowLayout? = nil) {
        super.init()
        self.layout = layout
    }

    // MARK: - Size for Item

    override func sizeForItem(at indexPath: IndexPath) -> CGSize {
        @Dependency(\.clientSession.entity.conversation.displayedMessages) var displayedMessages: [Message]

        guard let layout else { return .zero }
        return MainActor.assumeIsolated {
            typealias Floats = AppConstants.CGFloats.SystemMessageCell

            let contentInset = layout.collectionView?.contentInset ?? .zero
            let fullInset = contentInset.left + contentInset.right +
                layout.sectionInset.left + layout.sectionInset.right
            let cellWidth = (layout.collectionView?.bounds.width ?? 0) - fullInset

            guard let message = displayedMessages.itemAt(indexPath.section),
                  let attributedString = message.attributedSystemString else {
                return .init(width: cellWidth, height: Floats.defaultHeight)
            }

            let boundingRectangle = attributedString.boundingRect(
                with: .init(
                    width: cellWidth,
                    height: .greatestFiniteMagnitude
                ),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )

            let lineHeight = UIFont.systemFont(
                ofSize: Floats.activityStringSystemFontSize
            ).lineHeight + Floats.labelParagraphStyleLineSpacing

            let textHeight = min(
                boundingRectangle.height,
                lineHeight * Floats.labelNumberOfLines
            )

            let cellHeight = ceil(max(
                Floats.defaultHeight,
                textHeight + Floats.additionalVerticalPadding
            ))

            return .init(width: cellWidth, height: cellHeight)
        }
    }
}
