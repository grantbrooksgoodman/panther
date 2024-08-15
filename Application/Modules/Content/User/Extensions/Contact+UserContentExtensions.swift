//
//  Contact+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 26/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension Contact {
    /// Attempts to resolve a last name using all available content sources.
    var absoluteLastName: String {
        if !lastName.isBlank {
            return lastName
        } else if !firstName.isBlank {
            return firstName
        } else if !fullName.isBlank {
            return fullName
        } else if let phoneNumberString = phoneNumbers.first?.formattedString() {
            return phoneNumberString
        }

        return "�"
    }

    var tableViewSectionTitle: String {
        guard absoluteLastName.hasPrefix("+"),
              !absoluteLastName.digits.isBlank else { return .init(absoluteLastName.prefix(1)) }
        return "#"
    }
}
