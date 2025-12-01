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

private var contextMenuMessageIDKey: UInt8 = 0

extension MessageContentCell {
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
}
