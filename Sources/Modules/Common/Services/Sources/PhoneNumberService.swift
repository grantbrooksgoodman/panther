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

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import PhoneNumberKit

final class PhoneNumberService {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case possibleCallingCodesForNumbers
        case possibleHashesForNumbers
    }

    // MARK: - Dependencies

    @Dependency(\.currentLocale) private var currentLocale: Locale
    @Dependency(\.mainBundle) private var mainBundle: Bundle
    @Dependency(\.phoneNumberKit) private var phoneNumberKit: PhoneNumberKit
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    @Cached(CacheKey.possibleCallingCodesForNumbers) private var cachedPossibleCallingCodesForNumbers: [String: [String]]?
    @Cached(CacheKey.possibleHashesForNumbers) private var cachedPossibleHashesForNumbers: [String: [String]]?

    // MARK: - Computed Properties

    var deviceCallingCode: String {
        guard let regionCode = currentLocale.region?.identifier,
              let callingCode = callingCodes[regionCode] else { return "1" }
        return callingCode
    }

    private var callingCodes: [String: String] { services.propertyLists.callingCodes }
    private var lookupTables: [String: [String]] { services.propertyLists.lookupTables }

    // MARK: - Calling Code Determination

    func possibleCallingCodes(for number: String) -> [String]? {
        if let cachedPossibleHashesForNumbers,
           let cachedValue = cachedPossibleHashesForNumbers[number] {
            return cachedValue
        }

        guard let countryCodes = matchingCountryCodes(for: number) ?? callingCodes(for: number.count),
              !countryCodes.isEmpty else { return nil }

        var newCacheValue = cachedPossibleHashesForNumbers ?? [:]
        newCacheValue[number] = countryCodes
        cachedPossibleHashesForNumbers = newCacheValue

        return countryCodes
    }

    func possibleCallingCodes(for numbers: [String]) -> [String]? {
        var callingCodes = [String]()

        for number in numbers {
            guard let candidates = possibleCallingCodes(for: number) else { continue }
            callingCodes.append(contentsOf: candidates)
        }

        return callingCodes.isEmpty ? nil : callingCodes
    }

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

        return matches.isEmpty ? nil : matches.sorted()
    }

    // MARK: - Example National Number String

    func exampleNationalNumberString(for regionCode: String) -> String {
        let usNumberString = "(555) 555-5555"
        guard regionCode != "US" else { return usNumberString }

        if let regionMetadata = phoneNumberKit.metadata(for: regionCode),
           let description = regionMetadata.mobile,
           let exampleNumber = description.exampleNumber {
            return PhoneNumber(exampleNumber).partiallyFormatted(forRegion: regionCode)
        }

        return usNumberString
    }

    // MARK: - Hash Generation

    func possibleHashes(for number: String) -> [String]? {
        if let cachedPossibleCallingCodesForNumbers,
           let cachedValue = cachedPossibleCallingCodesForNumbers[number] {
            return cachedValue
        }

        var hashes = [number.encodedHash]

        if let countryCodes = matchingCountryCodes(for: number) {
            countryCodes.forEach { code in
                hashes.append(number.dropPrefix(code.count).encodedHash)
            }
        }

        var newCacheValue = cachedPossibleCallingCodesForNumbers ?? [:]
        newCacheValue[number] = hashes
        cachedPossibleCallingCodesForNumbers = newCacheValue

        return hashes
    }

    func possibleHashes(for numbers: [String]) -> [String]? {
        var hashes = [String]()

        for number in numbers {
            guard let candidates = possibleHashes(for: number) else { continue }
            hashes.append(contentsOf: candidates)
        }

        return hashes.isEmpty ? nil : hashes
    }

    // MARK: - Length Validation

    func numberIsValidLength(_ length: Int, for callingCode: String) -> Bool {
        guard let callingCodesForNumberLength = lookupTables[String(length)],
              callingCodesForNumberLength.contains(callingCode) else { return false }
        return true
    }
}
