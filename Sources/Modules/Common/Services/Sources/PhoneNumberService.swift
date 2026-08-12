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

/// Use ``PhoneNumberService`` to derive calling codes, hashes, and formatting details from
/// phone number strings.
///
/// Derivations rely on the app's bundled phone number reference data; results are cached in
/// memory.
final class PhoneNumberService {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case possibleCallingCodesForNumbers
        case possibleHashesForNumbers
    }

    // MARK: - Dependencies

    @Dependency(\.currentLocale) private var currentLocale: Locale
    @Dependency(\.mainBundle) private var mainBundle: Bundle
    @Dependency(\.phoneNumberKit) private var phoneNumberKit: PhoneNumberKit.PhoneNumberUtility
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    @Cached(CacheKey.possibleCallingCodesForNumbers) private var cachedPossibleCallingCodesForNumbers: [String: [String]]?
    @Cached(CacheKey.possibleHashesForNumbers) private var cachedPossibleHashesForNumbers: [String: [String]]?

    // MARK: - Computed Properties

    /// The calling code for the device's current region, or `1` if it cannot be determined.
    var deviceCallingCode: String {
        guard let regionCode = currentLocale.region?.identifier,
              let callingCode = callingCodes[regionCode] else { return "1" }
        return callingCode
    }

    private var callingCodes: [String: String] {
        services.propertyLists.callingCodes
    }

    private var lookupTables: [String: [String]] {
        services.propertyLists.lookupTables
    }

    // MARK: - Calling Code Determination

    /// Returns the calling codes that could plausibly apply to the given number string.
    ///
    /// A calling code matches if the number begins with it and the remaining digits form a
    /// valid length for that code; otherwise, candidates are derived from the number's length
    /// alone. Results are cached in memory per number.
    ///
    /// - Parameter number: The phone number string to evaluate, containing digits only.
    ///
    /// - Returns: The candidate calling codes; otherwise, `nil` if none could be derived.
    func possibleCallingCodes(for number: String) -> [String]? {
        if let cachedPossibleCallingCodesForNumbers,
           let cachedValue = cachedPossibleCallingCodesForNumbers[number] {
            return cachedValue
        }

        guard let countryCodes = matchingCountryCodes(for: number) ?? callingCodes(for: number.count),
              !countryCodes.isEmpty else { return nil }

        var newCacheValue = cachedPossibleCallingCodesForNumbers ?? [:]
        newCacheValue[number] = countryCodes
        cachedPossibleCallingCodesForNumbers = newCacheValue

        return countryCodes
    }

    /// Returns the combined candidate calling codes for the given number strings.
    ///
    /// Numbers for which no candidates could be derived are skipped.
    ///
    /// - Parameter numbers: The phone number strings to evaluate, containing digits only.
    ///
    /// - Returns: The concatenated candidate calling codes for each number; otherwise, `nil`
    ///   if none could be derived.
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

    /// Returns an example national phone number for the given region, formatted for display.
    ///
    /// If no example exists for the region, a United States example is returned.
    ///
    /// - Parameter regionCode: The region code for which to produce an example.
    ///
    /// - Returns: The formatted example number.
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

    /// Returns the encoded hashes under which the given number string may be stored.
    ///
    /// The result contains the hash of the full number, plus the hash of the number with each
    /// plausible calling code prefix removed. Results are cached in memory per number.
    ///
    /// - Parameter number: The phone number string to evaluate, containing digits only.
    ///
    /// - Returns: The candidate hashes.
    func possibleHashes(for number: String) -> [String]? {
        if let cachedPossibleHashesForNumbers,
           let cachedValue = cachedPossibleHashesForNumbers[number] {
            return cachedValue
        }

        var hashes = [number.encodedHash]

        if let countryCodes = matchingCountryCodes(for: number) {
            for code in countryCodes {
                hashes.append(number.dropPrefix(code.count).encodedHash)
            }
        }

        var newCacheValue = cachedPossibleHashesForNumbers ?? [:]
        newCacheValue[number] = hashes
        cachedPossibleHashesForNumbers = newCacheValue

        return hashes
    }

    /// Returns the combined candidate hashes for the given number strings.
    ///
    /// Numbers for which no candidates could be derived are skipped.
    ///
    /// - Parameter numbers: The phone number strings to evaluate, containing digits only.
    ///
    /// - Returns: The concatenated candidate hashes for each number; otherwise, `nil` if none
    ///   could be derived.
    func possibleHashes(for numbers: [String]) -> [String]? {
        var hashes = [String]()

        for number in numbers {
            guard let candidates = possibleHashes(for: number) else { continue }
            hashes.append(contentsOf: candidates)
        }

        return hashes.isEmpty ? nil : hashes
    }

    // MARK: - Length Validation

    /// Returns a Boolean value that indicates whether a national number of the given length is
    /// valid for the given calling code.
    ///
    /// - Parameters:
    ///   - length: The number of digits to validate.
    ///   - callingCode: The calling code against which to validate.
    ///
    /// - Returns: `true` if the length is valid for the calling code; otherwise, `false`.
    func numberIsValidLength(
        _ length: Int,
        for callingCode: String
    ) -> Bool {
        guard let callingCodesForNumberLength = lookupTables[String(length)],
              callingCodesForNumberLength.contains(callingCode) else { return false }
        return true
    }
}
