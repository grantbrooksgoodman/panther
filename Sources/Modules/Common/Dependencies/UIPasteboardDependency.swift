//
//  UIPasteboardDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

enum UIPasteboardDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> UIPasteboard {
        .general
    }
}

extension DependencyValues {
    var uiPasteboard: UIPasteboard {
        get { self[UIPasteboardDependency.self] }
        set { self[UIPasteboardDependency.self] = newValue }
    }
}
