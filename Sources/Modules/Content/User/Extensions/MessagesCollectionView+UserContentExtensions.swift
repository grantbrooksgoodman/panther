//
//  MessagesCollectionView+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/07/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import MessageKit

extension MessagesCollectionView {
    // MARK: - Properties

    /// The number of items in each section the data source
    /// currently reports.
    var dataSourceStructure: [Int] {
        guard let dataSource else { return [] }
        let sectionCount = dataSource.numberOfSections?(in: self) ?? 1
        return (0 ..< sectionCount).map {
            dataSource.collectionView(
                self,
                numberOfItemsInSection: $0
            )
        }
    }

    /// The number of items in each section the collection view
    /// currently displays.
    var displayedStructure: [Int] {
        (0 ..< numberOfSections).map { numberOfItems(inSection: $0) }
    }

    /// A Boolean value that indicates whether the sections and
    /// items the collection view displays match those its data
    /// source reports.
    var isSynchronizedWithDataSource: Bool {
        dataSourceStructure == displayedStructure
    }

    // MARK: - Methods

    /// Scrolls to the message with the given identifier.
    ///
    /// This method has no effect when no displayed message has the given identifier.
    ///
    /// - Parameters:
    ///   - messageID: The identifier of the message to scroll to.
    ///   - scrollPosition: The position at which to align the message.
    ///   - animated: A Boolean value that determines whether the scroll is animated.
    func scrollTo(
        messageID: String,
        at scrollPosition: UICollectionView.ScrollPosition = .top,
        animated: Bool = true
    ) {
        @Dependency(\.clientSession.entity.conversation.displayedMessages) var messages: [Message]
        guard let messageIndex = messages.firstIndex(where: { $0.id == messageID }),
              messageIndex < numberOfSections,
              numberOfItems(inSection: messageIndex) > 0 else { return }

        scrollToItem(
            at: .init(item: 0, section: messageIndex),
            at: scrollPosition,
            animated: animated
        )
    }
}
