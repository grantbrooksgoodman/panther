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

public extension NSAttributedString {
    static func messageCellString(_ text: String, foregroundColor: UIColor) -> NSAttributedString {
        @Dependency(\.chatPageViewService.alternateMessage) var alternateMessageService: AlternateMessageService?
        typealias Floats = AppConstants.CGFloats.UserContentExtensions.NSAttributedString

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = Floats.messageCellStringParagraphLineSpacing

        var font: UIFont = .systemFont(ofSize: Floats.messageCellStringSystemFontSize)
        if let alternateMessageService {
            font = alternateMessageService.textCellLabelFont
        }

        return .init(
            string: text,
            attributes: [
                .font: font.italicized,
                .foregroundColor: foregroundColor,
                .paragraphStyle: paragraphStyle,
            ]
        )
    }
}
