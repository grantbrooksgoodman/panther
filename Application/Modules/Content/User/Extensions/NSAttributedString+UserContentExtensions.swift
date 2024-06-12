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

/* 3rd-party */
import CoreArchitecture

public extension NSAttributedString {
    static func messageCellString(_ text: String, foregroundColor: UIColor) -> NSAttributedString {
        typealias Floats = AppConstants.CGFloats.UserContentExtensions.NSAttributedString

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = Floats.messageCellStringParagraphLineSpacing

        return .init(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: Floats.messageCellStringSystemFontSize).italicized,
                .foregroundColor: foregroundColor,
                .paragraphStyle: paragraphStyle,
            ]
        )
    }
}
