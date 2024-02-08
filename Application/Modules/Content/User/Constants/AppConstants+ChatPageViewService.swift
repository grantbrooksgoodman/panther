//
//  AppConstants+ChatPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 08/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum ChatPageViewService {
        public static let loadMoreMessagesMillisecondsDelay: CGFloat = 200
        public static let scrollToLastItemMillisecondsDelay: CGFloat = 10
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum ChatPageViewService {
        public static let buildInfoOverlayWindowSemanticTag = "BUILD_INFO_OVERLAY_WINDOW"
    }
}
