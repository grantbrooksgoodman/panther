//
//  Color+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 20/03/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

public extension Color {
    static var random: Color {
        var hue = Double.random(in: 0 ... 1)
        let saturation = Double.random(in: 0.6 ... 1)
        let brightness = Double.random(in: 0.5 ... 0.9)

        while let lastRandomColor,
              abs(hue - lastRandomColor.hue) < 0.15 { hue = Double.random(in: 0 ... 1) }

        lastRandomColor = (hue, saturation, brightness)
        return .init(hue: hue, saturation: saturation, brightness: brightness)
    }

    // swiftlint:disable:next large_tuple
    private static var lastRandomColor: (hue: Double, saturation: Double, brightness: Double)?
}
