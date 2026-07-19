//
//  MessageContentCell+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 30/10/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import ObjectiveC
import UIKit

/* 3rd-party */
import MessageKit

private nonisolated(unsafe) var contextMenuMessageIDKey: UInt8 = 0

extension MessageContentCell {
    // MARK: - Properties

    /// Swizzles `apply(_:)` to resolve an unresolved `.natural` avatar
    /// position before the base implementation reaches its `fatalError`.
    ///
    /// During forced layout passes triggered by keyboard dismiss animations,
    /// UIKit can apply layout attributes from `UICollectionViewFlowLayout`'s
    /// internal cache before `MessagesCollectionViewFlowLayout.configure(attributes:)`
    /// resolves the avatar position. This defensive swizzle prevents a crash
    /// by falling back to `.cellLeading`.
    static let swizzleApply: Void = {
        guard let original = class_getInstanceMethod(
            MessageContentCell.self,
            #selector(UICollectionReusableView.apply(_:))
        ), let swizzled = class_getInstanceMethod(
            MessageContentCell.self,
            #selector(_swizzled_apply(_:))
        ) else { return }

        method_exchangeImplementations(
            original,
            swizzled
        )
    }()

    var contextMenuMessageID: String? {
        get { objc_getAssociatedObject(self, &contextMenuMessageIDKey) as? String }
        set { objc_setAssociatedObject(self, &contextMenuMessageIDKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var hasContextMenuInteraction: Bool {
        guard let gestureRecognizers = messageContainerView.gestureRecognizers else { return false }
        return gestureRecognizers
            .compactMap { $0 as? UILongPressGestureRecognizer }
            .contains(where: { $0.minimumPressDuration == 0.22 }) // Arbitrary value specified in ContextualMenu package
    }

    // MARK: - Methods

    @objc
    private func _swizzled_apply(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) {
        if let attributes = layoutAttributes as? MessagesCollectionViewLayoutAttributes,
           attributes.avatarPosition.horizontal == .natural {
            attributes.avatarPosition.horizontal = .cellLeading
        }

        _swizzled_apply(layoutAttributes)
    }
}
