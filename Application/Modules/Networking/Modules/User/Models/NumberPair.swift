//
//  NumberPair.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct NumberPair: Codable, Equatable {
    // MARK: - Properties

    public let nationalNumberString: String
    public let users: [User]

    // MARK: - Init

    public init(_ nationalNumberString: String, users: [User]) {
        self.nationalNumberString = nationalNumberString
        self.users = users
    }
}

public extension Array where Element == NumberPair {
    var users: [User] {
        var users = [User]()
        forEach { element in
            users.append(contentsOf: element.users)
        }
        return users
    }
}
