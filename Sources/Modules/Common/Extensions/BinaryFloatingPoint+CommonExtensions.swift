//
//  BinaryFloatingPoint+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 27/03/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension BinaryFloatingPoint {
    var roundedString: String {
        String(Int((self * 100).rounded()))
    }
}
