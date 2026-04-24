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

/* Proprietary */
import AppSubsystem

extension Color {
    static var random: Color {
        lastRandomColor.projectedValue.withValue { lastRandomColor -> Color in
            var hue = Double.random(in: 0 ... 1)
            let saturation = Double.random(in: 0.6 ... 1)
            let brightness = Double.random(in: 0.5 ... 0.9)
            while let last = lastRandomColor,
                  abs(hue - last.hue) < 0.15 { hue = Double.random(in: 0 ... 1) }
            lastRandomColor = (hue, saturation, brightness)
            return Color(
                hue: hue,
                saturation: saturation,
                brightness: brightness
            )
        }
    }

    // swiftlint:disable:next large_tuple
    private static let lastRandomColor = LockIsolated<(
        hue: Double,
        saturation: Double,
        brightness: Double
    )?>(nil)
}
