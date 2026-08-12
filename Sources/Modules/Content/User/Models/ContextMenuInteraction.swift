//
//  ContextMenuInteraction.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/11/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// A namespace controlling whether message context menu interactions may begin.
@MainActor
enum ContextMenuInteraction {
    // MARK: - Properties

    /// A Boolean value that indicates whether context menu interactions may begin.
    private(set) static var canBegin = true

    // MARK: - Methods

    /// Sets whether context menu interactions may begin.
    ///
    /// Enabling interactions adds the context menu interaction to visible message cells;
    /// disabling them removes the long-press gesture from visible cells.
    ///
    /// - Parameter canBegin: A Boolean value that indicates whether interactions may begin.
    static func setCanBegin(_ canBegin: Bool) {
        @Dependency(\.chatPageViewService.contextMenu?.interaction) var contextMenuInteractionService: ContextMenuInteractionService?
        self.canBegin = canBegin

        guard let contextMenuInteractionService else { return }
        if canBegin {
            contextMenuInteractionService.addContextMenuInteractionToVisibleCellsOnce()
        } else {
            contextMenuInteractionService.removeUIMenuLongPressGestureForVisibleCells()
        }
    }
}
