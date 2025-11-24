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

/* 3rd-party */
import MessageKit

public final class MessageFlowLayout: MessagesCollectionViewFlowLayout {
    // MARK: - Properties

    private lazy var sizeCalculator = SizeCalculator(layout: self)

    // MARK: - Methods

    override public func cellSizeCalculatorForItem(at indexPath: IndexPath) -> CellSizeCalculator {
        if isSectionReservedForTypingIndicator(indexPath.section) {
            return typingIndicatorSizeCalculator
        }

        let message = messagesDataSource.messageForItem(at: indexPath, in: messagesCollectionView)
        if case .custom = message.kind {
            return sizeCalculator
        }

        return super.cellSizeCalculatorForItem(at: indexPath)
    }

    override public func messageSizeCalculators() -> [MessageSizeCalculator] {
        var superCalculators = super.messageSizeCalculators()
        superCalculators.append(sizeCalculator)
        return superCalculators
    }
}

private final class SizeCalculator: MessageSizeCalculator {
    // MARK: - Init

    override public init(layout: MessagesCollectionViewFlowLayout? = nil) {
        super.init()
        self.layout = layout
    }

    // MARK: - Size for Item

    override public func sizeForItem(at indexPath: IndexPath) -> CGSize {
        guard let layout else { return .zero }
        let collectionViewWidth = layout.collectionView?.bounds.width ?? 0
        let contentInset = layout.collectionView?.contentInset ?? .zero
        let inset = layout.sectionInset.left + layout.sectionInset.right + contentInset.left + contentInset.right
        return .init(
            width: collectionViewWidth - inset,
            height: 44
        )
    }
}
