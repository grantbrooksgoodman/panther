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
import UIKit

/* Proprietary */
import AppSubsystem

/// A contact from the user's address book.
///
/// ``Contact`` captures the subset of a system contact the app uses – identifier, name, phone
/// numbers, and thumbnail image data. Contact images are decoded once and cached in memory; use
/// ``ContactImageCache/clearCache()`` to release them.
struct Contact: Codable, EncodedHashable, Equatable {
    // MARK: - Properties

    /// The contact's first name.
    let firstName: String

    /// The contact's unique identifier.
    let id: String

    /// The contact's thumbnail image data, or `nil` if the contact has no image.
    let imageData: Data?

    /// The contact's last name.
    let lastName: String

    /// The contact's phone numbers.
    let phoneNumbers: [PhoneNumber]

    // MARK: - Computed Properties

    /// The strings that collectively define this instance's identity for hashing purposes,
    /// sorted alphabetically.
    ///
    /// Contains the contact's identifier, name components, phone number hashes, and encoded
    /// image data.
    var hashFactors: [String] {
        [
            firstName,
            id,
            lastName,
            phoneNumbers.map(\.encodedHash).joined(),
            imageData?.base64EncodedString() ?? "",
        ].sorted()
    }

    /// The contact's image, decoded from ``imageData`` and cached in memory, or `nil` if the
    /// contact has no image.
    var image: UIImage? {
        _ContactImageCache.cachedImagesForContactIDs?[id] ?? .init(data: imageData, id: id)
    }

    /// The contact's full name, composed from the non-blank components of their first and last
    /// names.
    var fullName: String {
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

    /// The uppercased first letters of each word of the contact's full name.
    var initials: String {
        fullName.components(separatedBy: " ").reduce(into: [String]()) { partialResult, string in
            if let firstLetter = string.components.first?.uppercased() {
                partialResult.append(firstLetter)
            }
        }.joined()
    }

    // MARK: - Init

    /// Creates a contact with the given identifier, name components, phone numbers, and image
    /// data.
    ///
    /// When image data is provided, its decoded image is added to the in-memory cache.
    ///
    /// - Parameters:
    ///   - id: The contact's unique identifier.
    ///   - firstName: The contact's first name.
    ///   - lastName: The contact's last name.
    ///   - phoneNumbers: The contact's phone numbers.
    ///   - imageData: The contact's thumbnail image data, or `nil` if the contact has no image.
    init(
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
        if let imageData {
            if var cachedImagesForContactIDs = _ContactImageCache.cachedImagesForContactIDs {
                cachedImagesForContactIDs[id] = .init(data: imageData)
                _ContactImageCache.cachedImagesForContactIDs = cachedImagesForContactIDs
            } else if let image = UIImage(data: imageData) {
                _ContactImageCache.cachedImagesForContactIDs = [id: image]
            }
        }
    }

    /// Creates a contact from the given system contact, compiling its name and de-duplicating
    /// its phone numbers.
    ///
    /// - Parameter contact: The system contact to convert.
    init(_ contact: CNContact) {
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

/// A namespace for managing the in-memory contact image cache.
enum ContactImageCache {
    /// Removes every cached contact image.
    static func clearCache() {
        _ContactImageCache.clearCache()
    }
}

private enum _ContactImageCache {
    // MARK: - Properties

    private static let _cachedImagesForContactIDs = LockIsolated<[String: UIImage]?>(nil)

    // MARK: - Computed Properties

    fileprivate static var cachedImagesForContactIDs: [String: UIImage]? {
        get { _cachedImagesForContactIDs.wrappedValue }
        set { _cachedImagesForContactIDs.wrappedValue = newValue }
    }

    // MARK: - Clear Cache

    fileprivate static func clearCache() {
        cachedImagesForContactIDs = nil
    }
}

private extension UIImage {
    convenience init?(
        data: Data?,
        id: String
    ) {
        guard let data else { return nil }
        if var cachedImagesForContactIDs = _ContactImageCache.cachedImagesForContactIDs {
            cachedImagesForContactIDs[id] = .init(data: data)
            _ContactImageCache.cachedImagesForContactIDs = cachedImagesForContactIDs
        } else if let image = UIImage(data: data) {
            _ContactImageCache.cachedImagesForContactIDs = [id: image]
        }

        self.init(data: data)
    }
}
