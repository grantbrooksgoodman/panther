//
//  Array+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public extension Array where Element == ContactPair {
    func queried(by searchTerm: String) -> [ContactPair] {
        @Dependency(\.chatPageViewService.recipientBar?.contactSelectionUI) var recipientBarContactSelectionUIService: RecipientBarContactSelectionUIService?
        guard !searchTerm.isEmpty else { return self } // Still want to capture pure whitespace, hence .isEmpty and not .isBlank.
        return filter { "\($0.contact)".lowercased().contains(searchTerm.lowercased()) }
            .filter { !(recipientBarContactSelectionUIService?.selectedContactPairs ?? []).contains($0) }
    }
}

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
