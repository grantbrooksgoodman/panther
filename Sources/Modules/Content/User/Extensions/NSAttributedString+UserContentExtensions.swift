//
//  NSAttributedString+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 09/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

@MainActor
extension NSAttributedString {
    // MARK: - Emphasizing Mentions of ChatGPT

    /// Returns a copy of the attributed string with each mention of
    /// ChatGPT emphasized in bold.
    ///
    /// When the current conversation does not include ChatGPT, the
    /// attributed string is returned unchanged.
    ///
    /// - Returns: The attributed string with mentions emphasized.
    func emphasizingMentionsOfChatGPT() -> NSAttributedString {
        @Dependency(\.clientSession.entity.conversation.currentConversation) var currentConversation: Conversation?
        guard currentConversation?.includesChatGPT == true else { return self }

        let term = AppConstants.Strings.ChatGPTPrompt.mentionToken
        let emphasized = NSMutableAttributedString(attributedString: self)
        var searchRange = NSRange(location: 0, length: emphasized.length)

        while searchRange.location < emphasized.length {
            let range = (emphasized.string as NSString).range(
                of: term,
                options: .caseInsensitive,
                range: searchRange
            )

            guard range.location != NSNotFound else { break }
            if let font = emphasized.attribute(
                .font,
                at: range.location,
                effectiveRange: nil
            ) as? UIFont {
                emphasized.addAttribute(
                    .font,
                    value: font.bolded,
                    range: range
                )
            }

            searchRange = NSRange(
                location: range.upperBound,
                length: emphasized.length - range.upperBound
            )
        }

        return emphasized
    }

    // MARK: - Message Cell String

    /// Returns an attributed string styled for a message cell.
    ///
    /// - Parameters:
    ///   - text: The text to style.
    ///   - foregroundColor: The color of the text.
    ///   - italicized: A Boolean value that determines whether the text is italicized.
    ///
    /// - Returns: The styled attributed string.
    static func messageCellString(
        _ text: String,
        foregroundColor: UIColor,
        italicized: Bool
    ) -> NSAttributedString {
        @Dependency(\.chatPageViewService.alternateMessage) var alternateMessageService: AlternateMessageService?
        typealias Floats = AppConstants.CGFloats.UserContentExtensions.NSAttributedString

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = Floats.messageCellStringParagraphLineSpacing

        var font: UIFont = .systemFont(ofSize: Floats.messageCellStringSystemFontSize)
        if let alternateMessageService { font = alternateMessageService.textCellLabelFont }
        font = font.regularWeight
        if italicized { font = font.italicized }

        return .init(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: foregroundColor,
                .paragraphStyle: paragraphStyle,
            ]
        )
    }
}
