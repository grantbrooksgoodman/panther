//
//  UITheme+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 29/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension UITheme {
    var nonEnglishName: String? {
        switch name {
        case "Default":
            return "Normal"

        case "Bluesky":
            return "Blue"

        case "Dusk":
            return "Orange"

        case "Firebrand":
            return "Red"

        case "Twilight":
            return "Purple"

        default:
            return nil
        }
    }
}
