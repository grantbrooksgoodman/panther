//
//  User+EntitySessionExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension User {
    enum DataType: CaseIterable {
        case conversations
        case messages
        case users
    }
}
