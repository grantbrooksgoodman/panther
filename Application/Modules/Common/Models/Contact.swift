//
//  Contact.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Contacts
import Foundation

/* 3rd-party */
import CoreArchitecture

public struct Contact: Codable, EncodedHashable, Equatable {
    // MARK: - Properties

    // Array
    public let phoneNumbers: [PhoneNumber]
    public var hashFactors: [String] {
        [
            firstName,
            id,
            lastName,
            phoneNumbers.map(\.encodedHash).joined(),
            imageData?.base64EncodedString() ?? "",
        ]
    }

    // Data
    public let imageData: Data?

    // String
    public let firstName: String
    public let id: String
    public let lastName: String

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

    public var initials: String {
        fullName.components(separatedBy: " ").reduce(into: [String]()) { partialResult, string in
            if let firstLetter = string.components.first?.uppercased() {
                partialResult.append(firstLetter)
            }
        }.joined()
    }

    // MARK: - Init

    public init(
        _ id: String,
        firstName: String,
        lastName: String,
        phoneNumbers: [PhoneNumber],
        imageData: Data?
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumbers = phoneNumbers
        self.imageData = imageData
    }

    public init(_ contact: CNContact) {
        @Dependency(\.contactNameService) var contactNameService: ContactNameService
        let compiledName = contactNameService.name(for: contact)
        self.init(
            contact.identifier,
            firstName: compiledName.firstName,
            lastName: compiledName.lastName,
            phoneNumbers: contact.phoneNumbers.asPhoneNumbers.unique,
            imageData: contact.thumbnailImageData
        )
    }
}

/* MARK: ContactNameService Dependency */

private enum ContactNameServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> ContactNameService {
        .init()
    }
}

private extension DependencyValues {
    var contactNameService: ContactNameService {
        get { self[ContactNameServiceDependency.self] }
        set { self[ContactNameServiceDependency.self] = newValue }
    }
}
