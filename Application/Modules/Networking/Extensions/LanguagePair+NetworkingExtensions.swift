//
//  LanguagePair+NetworkingExtensions.swift
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
        let notAutoidentical = from != to
        let isFromValid = !from.isEmpty && from.count == 2
        let isToValid = !to.isEmpty && to.count == 2
        return notAutoidentical && isFromValid && isToValid
    }
}
