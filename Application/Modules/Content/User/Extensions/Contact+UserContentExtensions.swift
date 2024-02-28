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
    var tableViewSectionTitle: String {
        guard lastName.hasPrefix("+"),
              !lastName.digits.isBlank else { return .init(lastName.prefix(1)) }
        return "#"
    }
}
