//
//  UITextView+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 27/10/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

extension UITextView {
    /// Emphasizes each mention of ChatGPT in the text view's text in
    /// bold, preserving the selection.
    ///
    /// Text typed after a mention returns to the regular weight. This
    /// method has no effect when the current conversation does not
    /// include ChatGPT, or when the text is already emphasized.
    func emphasizeMentionsOfChatGPT() {
        guard let font else { return }

        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: font.regularWeight,
            .foregroundColor: textColor ?? UIColor.label,
        ]

        let emphasized = NSAttributedString(
            string: text,
            attributes: baseAttributes
        ).emphasizingMentionsOfChatGPT()

        guard !emphasized.isEqual(to: attributedText) else { return }

        let selectedRange = selectedRange
        attributedText = emphasized
        self.selectedRange = selectedRange
        typingAttributes = baseAttributes
    }
}
