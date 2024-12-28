//
//  UIColor+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

public extension UIColor {
    // MARK: - Properties

    var hexCode: Int? {
        guard let components = cgColor.components,
              components.count >= 4 else { return nil }

        let red = Int(components[0] * 255.0)
        let green = Int(components[1] * 255.0)
        let blue = Int(components[2] * 255.0)
        let alpha = Int(components[3] * 255.0)

        return (alpha << 24) | (red << 16) | (green << 8) | blue
    }

    // MARK: - Methods

    func darker(by percentage: CGFloat = 30) -> UIColor? {
        adjust(by: -1 * abs(percentage))
    }

    func lighter(by percentage: CGFloat = 30) -> UIColor? {
        adjust(by: abs(percentage))
    }

    private func adjust(by percentage: CGFloat) -> UIColor? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return .init(
            red: min(red + percentage / 100, 1),
            green: min(green + percentage / 100, 1),
            blue: min(blue + percentage / 100, 1),
            alpha: alpha
        )
    }
}
