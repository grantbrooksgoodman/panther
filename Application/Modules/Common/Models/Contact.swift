//
//  Contact.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct Contact: Codable, CompressedHashable, Equatable, Identifiable {
    // MARK: - Properties

    // Array
    public let phoneNumbers: [PhoneNumber]
    public var hashFactors: [String] {
        [
            firstName,
            lastName,
            phoneNumbers.map(\.compressedHash).joined(),
            imageData?.base64EncodedString() ?? "",
            id.uuidString,
        ]
    }

    // String
    public let firstName: String
    public let lastName: String

    // Other
    public let imageData: Data?
    public var id = UUID()

    // MARK: - Computed Properties

    public var fullName: String {
        if !firstName.isBlank,
           !lastName.isBlank {
            return "\(firstName) \(lastName)"
        } else if !firstName.isBlank {
            return firstName
        } else if !lastName.isBlank {
            return lastName
        }

        return .init()
    }

    // MARK: - Init

    public init(
        firstName: String,
        lastName: String,
        phoneNumbers: [PhoneNumber],
        imageData: Data?
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumbers = phoneNumbers
        self.imageData = imageData
    }
}
