//
//  TranslationInput+CoreNetworkingExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Translator

public extension TranslationInput {
    /// Tokenizes detected addresses, links, and phone numbers.
    var withTaggedDetectorAttributes: TranslationInput {
        var stringValue = value

        let detectorType: NSTextCheckingResult.CheckingType = [
            .address,
            .link,
            .phoneNumber,
        ]

        guard let dataDetector = try? NSDataDetector(types: detectorType.rawValue) else { return self }

        for taggableString in dataDetector.matches(
            in: stringValue,
            range: .init(location: 0, length: stringValue.utf16.count)
        ).compactMap({ Range($0.range, in: value) }).compactMap({ String(value[$0]) }) {
            stringValue = stringValue.replacingOccurrences(of: taggableString, with: "⌘\(taggableString)⌘")
        }

        guard stringValue != value else { return self }
        return .init(stringValue)
    }
}
