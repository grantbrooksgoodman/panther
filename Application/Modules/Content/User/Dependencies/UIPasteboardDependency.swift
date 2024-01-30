//
//  UIPasteboardDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 26/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import Redux

public enum UIPasteboardDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> UIPasteboard {
        .general
    }
}

public extension DependencyValues {
    var uiPasteboard: UIPasteboard {
        get { self[UIPasteboardDependency.self] }
        set { self[UIPasteboardDependency.self] = newValue }
    }
}
