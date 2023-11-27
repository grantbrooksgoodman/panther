//
//  PhoneNumberService.swift
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

public struct PhoneNumberService {
    // MARK: - Dependencies

    @Dependency(\.mainBundle) private var mainBundle: Bundle
    @Dependency(\.regionDetailService) private var regionDetailService: RegionDetailService
    @Dependency(\.commonPropertyLists) private var commonPropertyLists: CommonPropertyLists
    @Dependency(\.phoneNumberKit) private var phoneNumberKit: PhoneNumberKit

    // MARK: - Computed Properties

    private var callingCodes: [String: String] { commonPropertyLists.callingCodes }
    private var lookupTables: [String: [String]] { commonPropertyLists.lookupTables }

    // MARK: - Calling Code Determination

    private func callingCodes(for numberLength: Int) -> [String]? {
        guard !lookupTables.isEmpty,
              let callingCodesForNumberLength = lookupTables[.init(numberLength)] else { return nil }
        return callingCodesForNumberLength
    }

    private func matchingCountryCodes(for number: String) -> [String]? {
        guard !callingCodes.isEmpty,
              !lookupTables.isEmpty else { return nil }

        let callingCodes = callingCodes.values
        var matches = [String]()

        for code in Array(callingCodes).unique where number.hasPrefix(code) {
            let rawNumberLengthString = String(number.dropPrefix(code.count).count)
            guard let callingCodesForNumberLength = lookupTables[rawNumberLengthString],
                  callingCodesForNumberLength.contains(code) else { continue }
            matches.append(code)
        }

        return matches.isEmpty ? nil : matches
    }

    public func possibleCallingCodes(for number: String) -> [String]? {
        guard let countryCodes = matchingCountryCodes(for: number) else { return callingCodes(for: number.count) }
        return countryCodes
    }

    // MARK: - Hash Generation

    public func possibleHashes(for number: String) -> [String]? {
        var hashes = [number.compressedHash]

        if let countryCodes = matchingCountryCodes(for: number) {
            countryCodes.forEach { code in
                hashes.append(number.dropPrefix(code.count).compressedHash)
            }
        }

        return hashes.isEmpty ? nil : hashes
    }

    public func possibleHashes(for numbers: [String]) -> [String] {
        var hashes = [String]()

        for number in numbers {
            guard let candidates = possibleHashes(for: number) else { continue }
            hashes.append(contentsOf: candidates)
        }

        return hashes
    }

    // MARK: - Length Verification

    public func numberIsValidLength(_ length: Int, for callingCode: String) -> Bool {
        guard let callingCodesForNumberLength = lookupTables[String(length)],
              callingCodesForNumberLength.contains(callingCode) else { return false }
        return true
    }

    // MARK: - Phone Number Formatting

    public func failsafeFormat(_ number: String) -> String {
        let digits = number.digits
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

    public func format(_ number: String, useFailsafe: Bool = true) -> String {
        let digits = number.digits
        let fallbackFormatted = useFailsafe ? failsafeFormat(digits) : digits

        guard let callingCodes = matchingCountryCodes(for: digits),
              callingCodes.count == 1 else { return fallbackFormatted }

        let callingCode = callingCodes[0]

        guard callingCode != "1" else {
            let keyString = "formattedInternationalStringValue"
            guard let formatted = CNPhoneNumber(stringValue: digits).value(forKey: keyString) as? String else { return fallbackFormatted }
            return formatted
        }

        guard let regionCode = regionDetailService.regionCode(callingCode: callingCode) else {
            return fallbackFormatted
        }

        let formattedNumber: String?

        do {
            let parsed = try phoneNumberKit.parse(number.digits, withRegion: regionCode)
            formattedNumber = phoneNumberKit.format(parsed, toType: .international)
        } catch { return fallbackFormatted }

        return formattedNumber ?? fallbackFormatted
    }
}
