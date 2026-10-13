//
//  ContextMenuHighlightable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

@MainActor
protocol ContextMenuHighlightable: AnyObject {
    func highlightElement(at point: CGPoint)
    func selectElement(at point: CGPoint) -> Bool
    func unhighlightAllElements()
}
