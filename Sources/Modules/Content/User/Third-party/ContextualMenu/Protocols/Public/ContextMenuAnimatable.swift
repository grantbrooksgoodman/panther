//
//  ContextMenuAnimatable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public protocol ContextMenuAnimatable {
    func appearAnimation(completion: (() -> Void)?)
    func disappearAnimation(completion: (() -> Void)?)
}

public extension ContextMenuAnimatable {
    func appearAnimation() { appearAnimation(completion: nil) }
    func disappearAnimation() { disappearAnimation(completion: nil) }
}
