//
//  PhoneNumber.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Contacts
import Foundation

/* 3rd-party */
import Redux

public struct PhoneNumber: Codable, CompressedHashable, Equatable {
    // MARK: - Properties

    public let callingCode: String
    public let internalFormattedString: String?
    public let label: String?
    public let nationalNumberString: String
    public let regionCode: String

    // MARK: - Computed Properties

    public var compiledNumberString: String { callingCode + nationalNumberString }
    public var hashFactors: [String] {
        [
            callingCode,
            internalFormattedString ?? "",
            label ?? "",
            nationalNumberString,
            regionCode,
        ]
    }

    // MARK: - Init

    public init(
        callingCode: String,
        nationalNumberString: String,
        regionCode: String,
        label: String?,
        internalFormattedString: String?
    ) {
        self.callingCode = callingCode.digits
        self.nationalNumberString = nationalNumberString.digits
        self.regionCode = regionCode
        self.label = label?.trimmingBorderedWhitespace.trimmingCharacters(in: .newlines)
        self.internalFormattedString = internalFormattedString
    }

    public init(_ cnLabeledPhoneNumber: CNLabeledValue<CNPhoneNumber>) {
        @Dependency(\.commonServices) var services: CommonServices

        var localizedLabel: String?
        if let label = cnLabeledPhoneNumber.label {
            localizedLabel = CNLabeledValue<NSString>.localizedString(forLabel: label)
        }

        let internalFormattedString = cnLabeledPhoneNumber.value.value(forKey: "formattedInternationalStringValue") as? String
        var numberValue = cnLabeledPhoneNumber.value.stringValue.digits

        var callingCode: String?
        if let countryCode = cnLabeledPhoneNumber.value.value(forKey: "countryCode") as? String,
           let callingCodeFromCountryCode = services.regionDetail.callingCode(regionCode: countryCode) {
            callingCode = callingCodeFromCountryCode
        } else if let internalFormattedString {
            callingCode = internalFormattedString.components(separatedBy: " ").first?.digits
        }

        let resolvedCallingCode = callingCode == nil ? services.phoneNumber.deviceCallingCode : callingCode!
        if numberValue.hasPrefix(resolvedCallingCode) {
            numberValue = numberValue.dropPrefix(resolvedCallingCode.count)
        }

        let regionCode = services.regionDetail.regionCode(callingCode: resolvedCallingCode) ?? services.regionDetail.deviceRegionCode

        self.init(
            callingCode: resolvedCallingCode,
            nationalNumberString: numberValue,
            regionCode: regionCode,
            label: localizedLabel,
            internalFormattedString: internalFormattedString
        )
    }

    public init(
        _ string: String,
        label: String? = nil
    ) {
        self.init(.init(stringValue: string), label: label)
    }

    private init(
        _ cnPhoneNumber: CNPhoneNumber,
        label: String?
    ) {
        self.init(.init(label: label, value: cnPhoneNumber))
    }
}
