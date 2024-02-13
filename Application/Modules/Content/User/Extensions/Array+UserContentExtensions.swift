//
//  Array+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension Array where Element == Message {
    var sortedByAscendingSentDate: [Message] { sorted(by: { $0.sentDate < $1.sentDate }) }
}

public extension Array where Element == String {
    /// Sorts the array with alphabetically-prefixed strings taking priority.
    var alphabeticallySorted: [String] {
        var alphabetical = [String]()
        var notAlphabetical = [String]()

        for string in self {
            guard let firstCharacter = string.lowercasedTrimmingWhitespaceAndNewlines.first,
                  firstCharacter.isLetter else {
                notAlphabetical.append(string)
                continue
            }

            alphabetical.append(string)
        }

        return alphabetical.sorted() + notAlphabetical.sorted()
    }
}
