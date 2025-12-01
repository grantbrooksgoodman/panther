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

struct ContactNameService {
    // MARK: - Name for Contact

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
