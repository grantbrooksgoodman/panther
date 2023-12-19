//
//  String+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension String {
    var isBlank: Bool {
        lowercasedTrimmingWhitespaceAndNewlines.isEmpty
    }
}
