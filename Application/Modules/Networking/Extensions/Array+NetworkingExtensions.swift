//
//  Array+NetworkingExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension Array where Element == String {
    /// An empty array qualified by a single value of "!".
    static var bangQualifiedEmpty: [String] { ["!"] }

    var isBangQualifiedEmpty: Bool { self == .bangQualifiedEmpty || isEmpty }
}
