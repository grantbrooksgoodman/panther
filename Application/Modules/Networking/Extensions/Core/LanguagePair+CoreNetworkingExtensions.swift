//
//  LanguagePair+CoreNetworkingExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Translator

extension LanguagePair: Validatable {
    public var isWellFormed: Bool {
        let isFromValid = !from.isBlank && from.count == 2
        let isToValid = !to.isBlank && to.count == 2
        return isFromValid && isToValid
    }
}

public extension LanguagePair {
    var isIdempotent: Bool { from == to }
}
