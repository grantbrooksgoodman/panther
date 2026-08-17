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

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import PhoneNumberKit

/// A phone number decomposed into its calling code, national number, and region.
///
/// ``PhoneNumber`` is the app's canonical phone number representation. Its
/// ``compiledNumberString`` identifies a number across the app, such as when matching contacts
/// to registered users.
///
/// Create phone numbers from raw strings or system contact values; the initializers derive the
/// calling code and region using the device's region and number length validation when the
/// source does not specify them.
///
/// - Important: Equality and hashing derive from ``hashFactors``, which include the number's
///   ``label`` and ``internalFormattedString`` in addition to its digits. Two phone numbers with
///   the same digits but different labels are not equal.
final class PhoneNumber: Codable, EncodedHashable, Hashable, @unchecked Sendable {
    // MARK: - Properties

    /// The number's calling code, containing digits only.
    let callingCode: String

    /// The system-provided international format of the number, or `nil`. Used as a formatting
    /// fallback.
    let internalFormattedString: String?

    /// The label associated with the number, such as Home or Mobile, or `nil`.
    let label: String?

    /// The number's national portion, containing digits only.
    let nationalNumberString: String

    /// The code of the region the number belongs to.
    let regionCode: String

    private var formattedString: String?
    private var formattedStringRegionCode: String?

    // MARK: - Computed Properties

    /// The number's compiled number string.
    ///
    /// A compiled number string is a phone number's calling code followed by its national
    /// number, containing digits only.
    var compiledNumberString: String {
        callingCode + nationalNumberString
    }

    /// The strings that collectively define this instance's identity for hashing purposes,
    /// sorted alphabetically.
    ///
    /// Contains the calling code, national number, region code, label, and internal formatted
    /// string.
    var hashFactors: [String] {
        [
            callingCode,
            internalFormattedString ?? "",
            label ?? "",
            nationalNumberString,
            regionCode,
        ].sorted()
    }

    // MARK: - Init

    /// Creates a phone number with the given components.
    ///
    /// The calling code and national number are reduced to their digits, and the label is
    /// trimmed of surrounding whitespace and newlines.
    ///
    /// - Parameters:
    ///   - callingCode: The number's calling code.
    ///   - nationalNumberString: The number's national portion.
    ///   - regionCode: The code of the region the number belongs to.
    ///   - label: The label associated with the number, if any.
    ///   - internalFormattedString: The system-provided international format of the number, if
    ///     any.
    init(
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

    /// Creates a phone number from the given labeled system contact value.
    ///
    /// The initializer derives the calling code by testing the number's possible calling codes
    /// against the device's, then falling back to the system-provided formatted string and the
    /// value's country code. The region is derived similarly, preferring the device's region.
    /// Components that cannot be derived fall back to the device's calling code and region.
    ///
    /// - Parameter cnLabeledPhoneNumber: The labeled system contact value to convert.
    convenience init(_ cnLabeledPhoneNumber: CNLabeledValue<CNPhoneNumber>) {
        @Dependency(\.commonServices) var services: CommonServices

        var localizedLabel: String?
        if let label = cnLabeledPhoneNumber.label {
            localizedLabel = CNLabeledValue<NSString>.localizedString(
                forLabel: label
            )
        }

        let countryCode = cnLabeledPhoneNumber
            .value
            .value(
                forKey: "countryCode"
            ) as? String

        let internalFormattedString = cnLabeledPhoneNumber
            .value
            .value(
                forKey: "formattedInternationalStringValue"
            ) as? String

        var numberValue = cnLabeledPhoneNumber.value.stringValue.digits

        var callingCode: String?
        var regionCode: String?

        if let possibleCallingCodes = services
            .phoneNumber
            .possibleCallingCodes(for: numberValue),
            possibleCallingCodes.contains(services.phoneNumber.deviceCallingCode) ||
            possibleCallingCodes.count == 1,
            let derivedCallingCode = possibleCallingCodes.first(where: {
                $0 == services.phoneNumber.deviceCallingCode
            }) ?? possibleCallingCodes.first,
            !derivedCallingCode.isBlank {
            callingCode = derivedCallingCode
        } else if let internalFormattedString,
                  let callingCodeFromInternalFormattedString = internalFormattedString.components(separatedBy: " ").first?.digits,
                  !callingCodeFromInternalFormattedString.isBlank,
                  callingCodeFromInternalFormattedString.count < 4 {
            callingCode = callingCodeFromInternalFormattedString
        } else if let countryCode,
                  let callingCodeFromCountryCode = services
                  .regionDetail
                  .callingCode(regionCode: countryCode),
                  !callingCodeFromCountryCode.isBlank {
            callingCode = callingCodeFromCountryCode
        }

        var resolvedCallingCode = callingCode ?? services.phoneNumber.deviceCallingCode
        if numberValue.hasPrefix(resolvedCallingCode) {
            numberValue = numberValue.dropPrefix(resolvedCallingCode.count)
        }

        if !services.phoneNumber.numberIsValidLength(
            numberValue.count,
            for: resolvedCallingCode
        ) {
            resolvedCallingCode = services.phoneNumber.possibleCallingCodes(
                for: numberValue
            )?.first ?? resolvedCallingCode
            if resolvedCallingCode.isBlank {
                resolvedCallingCode = services.phoneNumber.deviceCallingCode
            }
        }

        if let possibleRegionCodes = services
            .regionDetail
            .regionCodes(by: .callingCode(resolvedCallingCode)),
            possibleRegionCodes.contains(services.regionDetail.deviceRegionCode) {
            regionCode = services.regionDetail.deviceRegionCode
        } else if resolvedCallingCode == "1" {
            regionCode = "US"
        } else if let derivedRegionCode = services
            .regionDetail
            .regionCode(by: .callingCode(resolvedCallingCode)),
            derivedRegionCode != Localized(.multiple).wrappedValue,
            !derivedRegionCode.isBlank {
            regionCode = derivedRegionCode
        } else if let countryCode,
                  !countryCode.isBlank {
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

    /// Creates a phone number from the given string, deriving its components.
    ///
    /// - Parameters:
    ///   - string: The phone number string. Non-digit characters are ignored.
    ///   - label: The label to associate with the number, if any.
    convenience init(
        _ string: String,
        label: String? = nil
    ) {
        self.init(
            .init(stringValue: string.digits),
            label: label
        )
    }

    private convenience init(
        _ cnPhoneNumber: CNPhoneNumber,
        label: String?
    ) {
        self.init(.init(
            label: label,
            value: cnPhoneNumber
        ))
    }

    // MARK: - Formatted Strings

    /// Returns the number formatted for display, prefixed with its calling code.
    ///
    /// The formatted result is cached per region; formatting again for the same region returns
    /// the cached string.
    ///
    /// - Parameters:
    ///   - regionCode: The code of the region whose formatting conventions to use. Pass `nil`
    ///     to use the number's region.
    ///
    /// - Returns: The formatted number, prefixed with `+` and the calling code.
    func formattedString(
        regionCode: String? = nil
    ) -> String {
        let regionCode = regionCode ?? self.regionCode

        if let formattedStringRegionCode,
           formattedStringRegionCode == regionCode,
           let formattedString {
            return formattedString
        }

        let partiallyFormatted = partiallyFormatted(forRegion: regionCode)

        guard !partiallyFormatted.digits.hasPrefix(callingCode) else {
            guard !partiallyFormatted.hasPrefix("+") else { return partiallyFormatted }
            return "+\(partiallyFormatted.trimmingLeadingWhitespace)"
        }

        let formattedString = "+\(callingCode) \(partiallyFormatted.trimmingLeadingWhitespace)"
        self.formattedString = formattedString
        formattedStringRegionCode = regionCode

        return formattedString
    }

    /// Returns the national number formatted for the given region's conventions, without a
    /// calling code prefix.
    ///
    /// - Parameter regionCode: The code of the region whose formatting conventions to use. Pass
    ///   `nil` to use the number's region.
    ///
    /// - Returns: The formatted national number.
    func partiallyFormatted(
        forRegion regionCode: String? = nil
    ) -> String {
        @Dependency(\.commonServices) var services: CommonServices
        @Dependency(\.phoneNumberKit) var phoneNumberKit: PhoneNumberKit.PhoneNumberUtility

        let regionCode = regionCode ?? self.regionCode

        let partialNumberString = nationalNumberString.isEmpty ? compiledNumberString : nationalNumberString
        guard !partialNumberString.isEmpty else { return partialNumberString }

        var fullFormatAttempt = formattedString(
            regionCode: regionCode,
            includeCallingCode: false
        )

        guard let callingCode = services
            .regionDetail
            .callingCode(regionCode: regionCode) else { return fullFormatAttempt }

        guard fullFormatAttempt == failsafeFormat(partialNumberString) else {
            guard fullFormatAttempt.hasPrefix("+\(callingCode)") else {
                let partialFormatter = PartialFormatter(
                    utility: phoneNumberKit,
                    defaultRegion: regionCode.uppercased(),
                    withPrefix: false
                )

                return partialFormatter.formatPartial(partialNumberString)
            }

            fullFormatAttempt = fullFormatAttempt.removingOccurrences(of: ["+\(callingCode)"])
            return fullFormatAttempt.trimmingBorderedWhitespace
        }

        let partialFormatter = PartialFormatter(
            utility: phoneNumberKit,
            defaultRegion: regionCode.uppercased(),
            withPrefix: false
        )

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
        includeCallingCode: Bool
    ) -> String {
        @Dependency(\.phoneNumberKit) var phoneNumberKit: PhoneNumberKit.PhoneNumberUtility

        if callingCode == "1",
           let internalFormattedString,
           internalFormattedString.contains("+") {
            return internalFormattedString
        }

        let fallbackFormatted = failsafeFormat(compiledNumberString)
        let formattedNumber: String?

        do {
            let parsed = try phoneNumberKit.parse(
                nationalNumberString,
                withRegion: regionCode
            )

            formattedNumber = phoneNumberKit.format(
                parsed,
                toType: includeCallingCode ? .international : .national
            )
        } catch {
            return internalFormattedString ?? fallbackFormatted
        }

        return formattedNumber ?? internalFormattedString ?? fallbackFormatted
    }

    // MARK: - Equatable Conformance

    /// Returns a Boolean value that indicates whether two phone numbers are equal, comparing
    /// their ``hashFactors``.
    static func == (
        left: PhoneNumber,
        right: PhoneNumber
    ) -> Bool {
        left.hashFactors == right.hashFactors
    }

    // MARK: - Hashable Conformance

    /// Hashes the number's ``hashFactors``.
    func hash(into hasher: inout Hasher) {
        hasher.combine(hashFactors)
    }
}
