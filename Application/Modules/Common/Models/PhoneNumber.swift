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
import PhoneNumberKit
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

        let countryCode = cnLabeledPhoneNumber.value.value(forKey: "countryCode") as? String
        let internalFormattedString = cnLabeledPhoneNumber.value.value(forKey: "formattedInternationalStringValue") as? String
        var numberValue = cnLabeledPhoneNumber.value.stringValue.digits

        var callingCode: String?
        var regionCode: String?

        if let possibleCallingCodes = services.phoneNumber.possibleCallingCodes(for: numberValue),
           possibleCallingCodes.contains(services.phoneNumber.deviceCallingCode) || possibleCallingCodes.count == 1,
           let derivedCallingCode = possibleCallingCodes.first(where: { $0 == services.phoneNumber.deviceCallingCode }) ?? possibleCallingCodes.first {
            callingCode = derivedCallingCode
        } else if let internalFormattedString,
                  let callingCodeFromInternalFormattedString = internalFormattedString.components(separatedBy: " ").first?.digits,
                  callingCodeFromInternalFormattedString.count < 4 {
            callingCode = callingCodeFromInternalFormattedString
        } else if let countryCode,
                  let callingCodeFromCountryCode = services.regionDetail.callingCode(regionCode: countryCode) {
            callingCode = callingCodeFromCountryCode
        }

        let resolvedCallingCode = callingCode ?? services.phoneNumber.deviceCallingCode
        if numberValue.hasPrefix(resolvedCallingCode) {
            numberValue = numberValue.dropPrefix(resolvedCallingCode.count)
        }

        if let possibleRegionCodes = services.regionDetail.regionCodes(by: .callingCode(resolvedCallingCode)),
           possibleRegionCodes.contains(services.regionDetail.deviceRegionCode) {
            regionCode = services.regionDetail.deviceRegionCode
        } else if resolvedCallingCode == "1" {
            regionCode = "US"
        } else if let derivedRegionCode = services.regionDetail.regionCode(by: .callingCode(resolvedCallingCode)),
                  derivedRegionCode != Localized(.multiple).wrappedValue {
            regionCode = derivedRegionCode
        } else if let countryCode {
            regionCode = countryCode.uppercased()
        }

        self.init(
            callingCode: resolvedCallingCode,
            nationalNumberString: numberValue,
            regionCode: regionCode ?? services.regionDetail.deviceRegionCode,
            label: localizedLabel,
            internalFormattedString: internalFormattedString
        )
    }

    public init(
        _ string: String,
        label: String? = nil
    ) {
        self.init(.init(stringValue: string.digits), label: label)
    }

    private init(
        _ cnPhoneNumber: CNPhoneNumber,
        label: String?
    ) {
        self.init(.init(label: label, value: cnPhoneNumber))
    }

    // MARK: - Formatted Strings

    public func formattedString(regionCode: String? = nil, useFailsafe: Bool = true) -> String {
        let regionCode = regionCode ?? self.regionCode

        let fullFormatAttempt = formattedString(regionCode: regionCode, includeCallingCode: true, useFailsafe: useFailsafe)
        if fullFormatAttempt.contains("+") || fullFormatAttempt.contains(" ") {
            return fullFormatAttempt
        }

        return partiallyFormatted(forRegion: regionCode)
    }

    public func partiallyFormatted(forRegion regionCode: String? = nil) -> String {
        @Dependency(\.commonServices) var services: CommonServices

        let regionCode = regionCode ?? self.regionCode

        let partialNumberString = nationalNumberString.isEmpty ? compiledNumberString : nationalNumberString
        guard partialNumberString != "" else { return partialNumberString }

        var fullFormatAttempt = formattedString(regionCode: regionCode, includeCallingCode: false, useFailsafe: true)
        guard let callingCode = services.regionDetail.callingCode(regionCode: regionCode) else { return fullFormatAttempt }

        guard fullFormatAttempt == failsafeFormat(partialNumberString) else {
            guard fullFormatAttempt.hasPrefix("+\(callingCode)") else {
                let partialFormatter = PartialFormatter(defaultRegion: regionCode.uppercased(), withPrefix: false)
                return partialFormatter.formatPartial(partialNumberString)
            }

            fullFormatAttempt = fullFormatAttempt.removingOccurrences(of: ["+\(callingCode)"])
            return fullFormatAttempt.trimmingBorderedWhitespace
        }

        let partialFormatter = PartialFormatter(defaultRegion: regionCode.uppercased(), withPrefix: false)
        return partialFormatter.formatPartial(partialNumberString)
    }

    private func failsafeFormat(_ numberString: String) -> String {
        let digits = numberString.digits
        let evenDigits = digits.count % 2 == 0

        var formattedString = ""
        for (index, character) in digits.components.enumerated() {
            guard index != 0 else {
                formattedString = character
                continue
            }

            guard index % 2 == 0 else {
                formattedString = "\(formattedString)\(evenDigits ? "" : " ")\(character)"
                continue
            }

            formattedString = "\(formattedString)\(evenDigits ? " " : "")\(character)"
        }

        return formattedString.trimmingBorderedWhitespace
    }

    private func formattedString(
        regionCode: String,
        includeCallingCode: Bool,
        useFailsafe: Bool
    ) -> String {
        @Dependency(\.phoneNumberKit) var phoneNumberKit: PhoneNumberKit

        if callingCode == "1",
           let internalFormattedString,
           internalFormattedString.contains("+") {
            return internalFormattedString
        }

        let fallbackFormatted = useFailsafe ? failsafeFormat(compiledNumberString) : compiledNumberString
        let formattedNumber: String?

        do {
            let parsed = try phoneNumberKit.parse(nationalNumberString, withRegion: regionCode)
            formattedNumber = phoneNumberKit.format(parsed, toType: includeCallingCode ? .international : .national)
        } catch {
            return internalFormattedString ?? fallbackFormatted
        }

        return formattedNumber ?? internalFormattedString ?? fallbackFormatted
    }
}
