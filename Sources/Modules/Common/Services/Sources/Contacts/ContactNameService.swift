//
//  ContactNameService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Contacts
import Foundation

// TODO: Make this into a static enum.
/// Use ``ContactNameService`` to derive a display name from a Contacts framework contact.
struct ContactNameService {
    // MARK: - Name for Contact

    /// Returns the first and last name for the given contact.
    ///
    /// Resolution proceeds in the following order, using the first source that yields a value:
    ///
    /// 1. The contact's given and family names, falling back to their phonetic variants.
    /// 2. Whichever of the given or family name is present on its own.
    /// 3. The contact's nickname.
    /// 4. The contact's organization name, falling back to its phonetic variant.
    /// 5. The contact's first phone number, formatted for display.
    ///
    /// A value resolved from step 2 or 3 that consists of exactly two words is split into first
    /// and last names. Any other single value becomes the last name, with an empty first name.
    ///
    /// - Parameter contact: The contact whose name to resolve.
    ///
    /// - Returns: A tuple containing the resolved first and last names; both components are
    ///   empty if no source yields a value.
    func name(for contact: CNContact) -> (firstName: String, lastName: String) {
        let lastName = lastName(contact)
        let firstName = firstName(contact)

        if let lastName,
           let firstName {
            return (firstName, lastName)
        } else if let firstName {
            return splitName(firstName) ?? ("", firstName)
        } else if let lastName {
            return splitName(lastName) ?? ("", lastName)
        } else if let nickname = nickname(contact) {
            return splitName(nickname) ?? ("", nickname)
        } else if let organizationName = organizationName(contact) {
            return ("", organizationName)
        } else if let phoneNumber = contact.phoneNumbers.asPhoneNumbers.first?.formattedString() {
            return ("", phoneNumber)
        }

        return ("", "")
    }

    // MARK: - Auxiliary

    private func firstName(_ contact: CNContact) -> String? {
        let firstName = contact.givenName
        let phoneticFirstName = contact.phoneticGivenName
        return (firstName.isBlank ? (phoneticFirstName.isBlank ? nil : phoneticFirstName) : firstName)?.trimmingBorderedWhitespace
    }

    private func lastName(_ contact: CNContact) -> String? {
        let lastName = contact.familyName
        let phoneticLastName = contact.phoneticFamilyName
        return (lastName.isBlank ? (phoneticLastName.isBlank ? nil : phoneticLastName) : lastName)?.trimmingBorderedWhitespace
    }

    private func nickname(_ contact: CNContact) -> String? {
        let nickname = contact.nickname
        return (nickname.isBlank ? nil : nickname)?.trimmingBorderedWhitespace
    }

    private func organizationName(_ contact: CNContact) -> String? {
        let organizationName = contact.organizationName
        let phoneticOrganizationName = contact.phoneticOrganizationName
        return (organizationName.isBlank ? (phoneticOrganizationName.isBlank ? nil : phoneticOrganizationName) : organizationName)?.trimmingBorderedWhitespace
    }

    private func splitName(_ string: String) -> (firstName: String, lastName: String)? {
        let trimmed = string.trimmingBorderedWhitespace
        let components = trimmed.components(separatedBy: " ")
        guard components.count == 2 else { return nil }
        return (components[0].trimmingBorderedWhitespace, components[1].trimmingBorderedWhitespace)
    }
}
