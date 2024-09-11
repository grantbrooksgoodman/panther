//
//  Array+CoreNetworkingExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import Translator

public extension Array where Element == String {
    /// An empty array qualified by a single value of "!".
    static var bangQualifiedEmpty: [String] { ["!"] }
    var isBangQualifiedEmpty: Bool { isEmpty || allSatisfy(\.isBangQualifiedEmpty) }
}

public extension Array where Element == Translation {
    var isWellFormed: Bool {
        !isEmpty && allSatisfy(\.isWellFormed)
    }
}

public extension Array where Element == TranslationInput {
    var isWellFormed: Bool {
        !isEmpty && allSatisfy(\.isWellFormed)
    }
}
