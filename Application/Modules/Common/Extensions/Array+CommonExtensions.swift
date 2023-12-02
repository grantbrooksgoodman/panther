//
//  Array+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import ContactsUI
import Foundation

/* 3rd-party */
import Redux

public extension Array where Element == CNLabeledValue<CNPhoneNumber> {
    var asPhoneNumbers: [PhoneNumber] {
        @Dependency(\.phoneNumberService) var phoneNumberService: PhoneNumberService
        @Dependency(\.regionDetailService) var regionDetailService: RegionDetailService
        return map {
            var localizedLabel: String?
            if let label = $0.label {
                localizedLabel = CNLabeledValue<NSString>.localizedString(forLabel: label)
            }

            let internalFormattedString = $0.value.value(forKey: "formattedInternationalStringValue") as? String
            var numberValue = $0.value.stringValue.digits

            var callingCode: String?
            if let countryCode = $0.value.value(forKey: "countryCode") as? String,
               let callingCodeFromCountryCode = regionDetailService.callingCode(regionCode: countryCode) {
                callingCode = callingCodeFromCountryCode
            } else if let internalFormattedString,
                      internalFormattedString.hasPrefix("+") {
                callingCode = internalFormattedString.components(separatedBy: " ").first?.digits
            } else if let possibleCallingCodes = phoneNumberService.possibleCallingCodes(for: numberValue) {
                callingCode = possibleCallingCodes.first(where: { $0 == phoneNumberService.deviceCallingCode })
            }

            let resolvedCallingCode = callingCode == nil ? phoneNumberService.deviceCallingCode : callingCode!
            if numberValue.hasPrefix(resolvedCallingCode) {
                numberValue = numberValue.dropPrefix(resolvedCallingCode.count)
            }

            let regionCode = regionDetailService.regionCode(callingCode: resolvedCallingCode) ?? regionDetailService.deviceRegionCode

            return .init(
                callingCode: resolvedCallingCode,
                nationalNumberString: numberValue,
                regionCode: regionCode,
                label: localizedLabel,
                internalFormattedString: $0.value.value(forKey: "formattedInternationalStringValue") as? String
            )
        }
    }
}

public extension Array where Element == ContactPair {
    var contacts: [Contact] {
        map(\.contact)
    }
}

public extension Array where Element == NumberPair {
    var users: [User] {
        flatMap(\.users)
    }
}

public extension Array where Element == PhoneNumber {
    var compiledNumberStrings: [String] {
        map(\.compiledNumberString)
    }

    var labels: [String] {
        compactMap(\.label)
    }
}
