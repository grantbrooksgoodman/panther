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

public enum ContextMenuInteraction {
    // MARK: - Properties

    public private(set) static var canBegin = true

    // MARK: - Methods

    public static func setCanBegin(_ canBegin: Bool) {
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
