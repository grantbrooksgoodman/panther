//
//  String+CoreNetworkingExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension String {
    var alphaEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? self
    }

    var base64Decoded: String {
        guard let data = Data(base64Encoded: self),
              let string = String(data: data, encoding: .utf8) else { return self }
        return string
    }

    var base64Encoded: String {
        guard let data = data(using: .utf8) else { return self }
        return data.base64EncodedString()
    }

    static var bangQualifiedEmpty: String { "!" }

    var decodedTranslationComponents: (input: String, output: String)? {
        let components = components(separatedBy: "–")
        guard components.count == 2,
              let inputString = components[0].removingPercentEncoding,
              let outputString = components[1].removingPercentEncoding else { return nil }
        return (inputString, outputString)
    }

    var digits: String {
        components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }

    var englishLanguageName: String? {
        @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities

        guard self != "",
              lowercasedTrimmingWhitespaceAndNewlines != "",
              let languageCodes = RuntimeStorage.languageCodeDictionary,
              let name = languageCodes[self] ?? languageCodes[lowercasedTrimmingWhitespaceAndNewlines] else { return nil }

        let components = name.components(separatedBy: " (")
        guard !components.isEmpty else { return name.trimmingBorderedWhitespace }
        return components[0].trimmingBorderedWhitespace
    }

    var isBangQualifiedEmpty: Bool {
        isBlank || self == .bangQualifiedEmpty
    }

    var isBlank: Bool {
        lowercasedTrimmingWhitespaceAndNewlines.isEmpty
    }
}
