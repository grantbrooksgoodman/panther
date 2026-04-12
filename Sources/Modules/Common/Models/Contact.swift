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

struct Contact: Codable, EncodedHashable, Equatable {
    // MARK: - Properties

    let firstName: String
    let id: String
    let imageData: Data?
    let lastName: String
    let phoneNumbers: [PhoneNumber]

    // MARK: - Computed Properties

    var hashFactors: [String] {
        [
            firstName,
            id,
            lastName,
            phoneNumbers.map(\.encodedHash).joined(),
            imageData?.base64EncodedString() ?? "",
        ].sorted()
    }

    var image: UIImage? { _ContactImageCache.cachedImagesForContactIDs?[id] ?? .init(data: imageData, id: id) }

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

    var initials: String {
        fullName.components(separatedBy: " ").reduce(into: [String]()) { partialResult, string in
            if let firstLetter = string.components.first?.uppercased() {
                partialResult.append(firstLetter)
            }
        }.joined()
    }

    // MARK: - Init

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

enum ContactImageCache {
    static func clearCache() {
        _ContactImageCache.clearCache()
    }
}

private enum _ContactImageCache {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case imagesForContactIDs
    }

    // MARK: - Properties

    fileprivate static var cachedImagesForContactIDs: [String: UIImage]? {
        get { _cachedImagesForContactIDs.wrappedValue }
        set { _cachedImagesForContactIDs.wrappedValue = newValue }
    }

    private static let _cachedImagesForContactIDs = LockIsolated<[String: UIImage]?>(wrappedValue: nil)

    // MARK: - Clear Cache

    fileprivate static func clearCache() {
        cachedImagesForContactIDs = nil
    }
}

private extension UIImage {
    convenience init?(data: Data?, id: String) {
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
