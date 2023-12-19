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
import Redux

public struct PhoneNumberService {
    // MARK: - Dependencies

    @Dependency(\.currentLocale) private var currentLocale: Locale
    @Dependency(\.mainBundle) private var mainBundle: Bundle
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Computed Properties

    public var deviceCallingCode: String {
        guard let regionCode = currentLocale.region?.identifier,
              let callingCode = callingCodes[regionCode] else { return "1" }
        return callingCode
    }

    private var callingCodes: [String: String] { services.propertyLists.callingCodes }
    private var lookupTables: [String: [String]] { services.propertyLists.lookupTables }

    // MARK: - Calling Code Determination

    public func possibleCallingCodes(for number: String) -> [String]? {
        guard let countryCodes = matchingCountryCodes(for: number) else { return callingCodes(for: number.count) }
        return countryCodes
    }

    public func possibleCallingCodes(for numbers: [String]) -> [String]? {
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

        return matches.isEmpty ? nil : matches
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

    public func possibleHashes(for numbers: [String]) -> [String]? {
        var hashes = [String]()

        for number in numbers {
            guard let candidates = possibleHashes(for: number) else { continue }
            hashes.append(contentsOf: candidates)
        }

        return hashes.isEmpty ? nil : hashes
    }

    // MARK: - Length Verification

    public func numberIsValidLength(_ length: Int, for callingCode: String) -> Bool {
        guard let callingCodesForNumberLength = lookupTables[String(length)],
              callingCodesForNumberLength.contains(callingCode) else { return false }
        return true
    }
}
