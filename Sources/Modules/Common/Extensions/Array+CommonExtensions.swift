//
//  Array+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import ContactsUI
import Foundation

/* Proprietary */
import AppSubsystem

public extension Array where Element == CNLabeledValue<CNPhoneNumber> {
    var asPhoneNumbers: [PhoneNumber] {
        map { PhoneNumber($0) }
    }
}

public extension Array where Element == PhoneNumber {
    var compiledNumberStrings: [String] {
        map(\.compiledNumberString)
    }
}
