//
//  MenuElementView+Extensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

extension MenuElementView {
    // MARK: - Types

    struct Style {
        /* MARK: Properties */

        // Dictionary
        let defaultTitleAttributes: [NSAttributedString.Key: Any]
        let destructiveTitleAttributes: [NSAttributedString.Key: Any]

        // UIColor
        let backgroundColor: UIColor
        let defaultIconTint: UIColor
        let destructiveIconTint: UIColor
        let highlightedBackgroundColor: UIColor

        // Other
        let height: CGFloat
        let iconSize: CGSize

        /* MARK: Init */

        init(
            height: CGFloat = 44,
            backgroundColor: UIColor = .clear,
            highlightedBackgroundColor: UIColor = .black.withAlphaComponent(0.2),
            defaultTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.black,
            ],
            destructiveTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.red,
            ],
            defaultIconTint: UIColor = .black,
            destructiveIconTint: UIColor = .red,
            iconSize: CGSize = .init(width: 22, height: 22)
        ) {
            self.height = height
            self.backgroundColor = backgroundColor
            self.highlightedBackgroundColor = highlightedBackgroundColor
            self.defaultTitleAttributes = defaultTitleAttributes
            self.destructiveTitleAttributes = destructiveTitleAttributes
            self.defaultIconTint = defaultIconTint
            self.destructiveIconTint = destructiveIconTint
            self.iconSize = iconSize
        }
    }

    // MARK: - Methods

    static func iconTint(
        attributes: MenuElement.Attributes,
        style: MenuElementView.Style
    ) -> UIColor {
        switch attributes {
        case .destructive: return style.destructiveIconTint
        default: return style.defaultIconTint
        }
    }

    static func titleAttributes(
        attributes: MenuElement.Attributes,
        style: MenuElementView.Style
    ) -> [NSAttributedString.Key: Any] {
        switch attributes {
        case .destructive: return style.destructiveTitleAttributes
        default: return style.defaultTitleAttributes
        }
    }
}
