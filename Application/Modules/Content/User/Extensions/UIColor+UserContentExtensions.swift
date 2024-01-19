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
