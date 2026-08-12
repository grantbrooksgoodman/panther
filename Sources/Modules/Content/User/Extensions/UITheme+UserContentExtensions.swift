//
//  UITheme+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 29/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension UITheme {
    /// The theme's simplified, color-based name for display in non-English languages, or `nil` if
    /// it has none.
    var nonEnglishName: String? {
        switch name {
        case "Default":
            "Normal"

        case "Bluesky":
            "Blue"

        case "Dusk":
            "Orange"

        case "Firebrand":
            "Red"

        case "Twilight":
            "Purple"

        default:
            nil
        }
    }
}
