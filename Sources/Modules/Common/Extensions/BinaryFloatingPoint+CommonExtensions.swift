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
    /// The value multiplied by 100 and rounded to the nearest whole number, as a string.
    ///
    /// Use this property to display a fractional value – such as `0.75` – as a whole-number
    /// percentage string – in this case, `"75"`. The string does not include a percent sign.
    var roundedString: String {
        String(Int((self * 100).rounded()))
    }
}
