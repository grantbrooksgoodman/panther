//
//  String+NetworkingExtensions.swift
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
    var digits: String {
        components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }

    var prependingCurrentEnvironment: String {
        @Dependency(\.networking.config) var config: NetworkConfig
        return "\(config.environment.shortString)/\(trimmingBorderedForwardSlashes)"
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
