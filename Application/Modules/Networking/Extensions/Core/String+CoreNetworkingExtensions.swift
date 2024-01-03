//
//  String+CoreNetworkingExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

extension String: CompressedHashable {
    public var hashFactors: [String] {
        [self]
    }
}

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

    var isBangQualifiedEmpty: Bool {
        isBlank || self == .bangQualifiedEmpty
    }

    var prependingCurrentEnvironment: String {
        @Dependency(\.networking.config.environment.shortString) var environmentString: String
        return "\(environmentString)/\(trimmingBorderedForwardSlashes)"
    }

    var trimmingBorderedForwardSlashes: String {
        trimmingLeadingForwardSlashes.trimmingTrailingForwardSlashes
    }

    private var trimmingLeadingForwardSlashes: String {
        var string = self
        while string.hasPrefix("/") {
            string = string.dropPrefix()
        }

        return string
    }

    private var trimmingTrailingForwardSlashes: String {
        var string = self
        while string.hasSuffix("/") {
            string = string.dropSuffix()
        }

        return string
    }
}
