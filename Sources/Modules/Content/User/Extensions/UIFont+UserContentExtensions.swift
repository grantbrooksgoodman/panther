//
//  UIFont+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 08/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

extension UIFont {
    // MARK: - Properties

    /// A bold version of the font.
    var bolded: UIFont {
        withTraits(traits: .traitBold)
    }

    /// An italic version of the font.
    var italicized: UIFont {
        withTraits(traits: .traitItalic)
    }

    // MARK: - Methods

    private func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return .init(descriptor: descriptor, size: 0)
    }
}
