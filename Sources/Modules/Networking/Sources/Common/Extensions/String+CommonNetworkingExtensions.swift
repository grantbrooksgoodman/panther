//
//  String+CommonNetworkingExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension String {
    static var bangQualifiedEmpty: String { "!" }
    var isBangQualifiedEmpty: Bool { isBlank || self == .bangQualifiedEmpty }
    /// Prefixes the string to its first 32 characters.
    var shortened: String { .init(prefix(32)) }
}
