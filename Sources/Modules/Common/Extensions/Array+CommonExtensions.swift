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

extension [CNLabeledValue<CNPhoneNumber>] {
    /// The array's labeled Contacts framework phone numbers, converted to ``PhoneNumber``
    /// instances.
    var asPhoneNumbers: [PhoneNumber] {
        map { PhoneNumber($0) }
    }
}

extension [ContactPair] {
    /// The unique compiled number strings for every phone number belonging to the array's
    /// contacts.
    ///
    /// A compiled number string is a phone number's calling code followed by its national number,
    /// containing digits only.
    var compiledNumberStrings: [String] {
        reduce(into: [String]()) { partialResult, contactPair in
            partialResult.append(
                contentsOf: contactPair.compiledNumberStrings
            )
        }.unique
    }
}

extension [PhoneNumber] {
    /// The compiled number strings for every phone number in the array.
    ///
    /// A compiled number string is a phone number's calling code followed by its national number,
    /// containing digits only.
    var compiledNumberStrings: [String] {
        map(\.compiledNumberString)
    }
}
